# frozen_string_literal: true

class Channel::Evolution < ApplicationRecord
  include Channelable

  self.table_name = 'channel_evolution'

  EDITABLE_ATTRS = %i[
    instance_name
    api_key
    webhook_url
    webhook_secret
    provider_config
  ].freeze

  INSTANCE_NAME_PREFIX = 'evo-'
  WEBHOOK_PATH_PREFIX  = '/webhooks/evolution'

  enum state: {
    disconnected: 'disconnected',
    close:        'close',
    connecting:   'connecting',
    qrcode:       'qrcode',
    pairing:      'pairing',
    open:         'open',
    connected:    'connected',
    error:        'error'
  }

  validates :instance_name, uniqueness: true, allow_nil: true

  # Callbacks
  after_create_commit        :assign_instance_name!
  after_commit               :configure_webhook_if_needed, on: %i[create update]
  after_destroy_commit       :enqueue_delete_job
  before_save                :touch_state_timestamp, if: :will_save_change_to_state?

  # API esperada pelo Chatwoot
  def name = 'Evolution'

  def update_state!(new_state)
    update!(state: new_state, state_updated_at: Time.current)
  end

  def send_message(message)
    Evolution::SendMessageService.new(channel: self, message:).perform
  end

  def update_message(message, **attrs)
    Evolution::UpdateMessageService.new(channel: self, message:, **attrs).perform
  end

  def delete_message(message)
    Evolution::DeleteMessageService.new(channel: self, message:).perform
  end

  private

  # ===== Instance/Webhook helpers =====

  def assign_instance_name!
    return if instance_name.present?

    safe_update_column(:instance_name, generated_instance_name)
  end

  def configure_webhook_if_needed
    return unless webhook_configurable?

    url = computed_webhook_url
    return if url.blank?

    # Sempre tenta “upsert” no Evolution (idempotente), e só grava se mudou
    evo_client.set_webhook(instance_name, url)
    safe_update_column(:webhook_url, url) if webhook_url != url
  rescue StandardError => e
    log_evo_error("falha na configuração do webhook", e)
  end

  def enqueue_delete_job
    return unless deletable_instance?

    Evolution::DeleteInstanceJob.perform_later(
      base_url:      ENV.fetch('EVOLUTION_BASE_URL'),
      api_key:       api_key,
      instance_name: instance_name
    )
  end

  # ===== Predicados/derivados =====

  def generated_instance_name
    "#{INSTANCE_NAME_PREFIX}acc#{account_id}-ch#{id}"
  end

  def webhook_configurable?
    api_key.present? && instance_name.present? && inbox.present?
  end

  def deletable_instance?
    api_key.present? && instance_name.present?
  end

  def computed_webhook_url
    base = canonical_base_host
    return if base.blank? || inbox.blank?

    "#{base}#{WEBHOOK_PATH_PREFIX}/#{inbox.id}"
  end

  def canonical_base_host
    raw = ENV['FRONTEND_URL_TESTE'].presence ||
          Rails.application.routes.default_url_options[:host].to_s
    return if raw.blank?

    raw = "https://#{raw}" unless raw.include?('://')
    uri = URI.parse(raw)

    host = "#{uri.scheme}://#{uri.host}"
    host += ":#{uri.port}" if uri.port && ![80, 443].include?(uri.port)
    host
  rescue URI::InvalidURIError
    nil
  end

  def evo_client
    Evolution::Client.new(
      base_url: ENV.fetch('EVOLUTION_BASE_URL'),
      api_key:
        api_key.presence || ENV['EVOLUTION_API_KEY']
    )
  end

  # ===== Infra pequenas =====

  def touch_state_timestamp
    self.state_updated_at = Time.current
  end

  # evita writes desnecessários e validações
  def safe_update_column(attr, value)
    return if value.nil? || self[attr] == value

    # rubocop:disable Rails/SkipsModelValidations
    update_column(attr, value)
    # rubocop:enable Rails/SkipsModelValidations
  end

  def log_evo_error(msg, error)
    Rails.logger.error "[EVOLUTION] #{msg} channel=#{id} inbox=#{inbox_id rescue nil}: #{error.class} - #{error.message}"
  end
end
