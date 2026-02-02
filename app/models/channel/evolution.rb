# frozen_string_literal: true

# == Schema Information
#
# Table name: channel_evolution
#
#  id               :bigint           not null, primary key
#  api_key          :string
#  instance_name    :string
#  provider_config  :jsonb            not null
#  state            :string           default("disconnected"), not null
#  state_updated_at :datetime
#  webhook_secret   :string
#  webhook_url      :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  account_id       :integer          not null
#
# Indexes
#
#  index_channel_evolution_on_account_id     (account_id)
#  index_channel_evolution_on_instance_name  (instance_name) UNIQUE
#  index_channel_evolution_on_state          (state)
#
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
    close: 'close',
    connecting: 'connecting',
    qrcode: 'qrcode',
    pairing: 'pairing',
    open: 'open',
    connected: 'connected',
    error: 'error'
  }

  validates :instance_name, uniqueness: true, allow_nil: true

  # Callbacks
  after_create_commit        :assign_instance_name!
  after_destroy_commit       :cleanup_evolution_instance
  before_save                :touch_state_timestamp, if: :will_save_change_to_state?

  # API esperada pelo Chatwoot
  def name = 'Evolution'

  def phone_number
    provider_config['phone_number']
  end

  def phone_number=(value)
    self.provider_config = (provider_config || {}).merge('phone_number' => value)
  end

  def update_state!(new_state)
    update!(state: new_state, state_updated_at: Time.current)
  end

  def send_message(message)
    Evolution::SendMessageService.new(channel: self, message: message).perform
  end

  def update_message(message, **attrs)
    Evolution::UpdateMessageService.new(channel: self, message: message, **attrs).perform
  end

  def delete_message(message)
    Evolution::DeleteMessageService.new(channel: self, message: message).perform
  end

  private

  # ===== Instance/Webhook helpers =====

  def assign_instance_name!
    return if instance_name.present?

    safe_update_column(:instance_name, generated_instance_name)
  end

  def cleanup_evolution_instance
    return unless deletable_instance?

    client = Evolution::Client.new(
      base_url: ENV.fetch('EVOLUTION_BASE_URL'),
      api_key: api_key.presence || ENV.fetch('AUTHENTICATION_API_KEY', nil)
    )

    begin
      client.logout_instance(instance_name)
    rescue StandardError => e
      Rails.logger.warn("[Evolution] logout before delete failed channel=#{id} instance=#{instance_name}: #{e.class} #{e.message}")
    end

    begin
      client.delete_instance(instance_name)
    rescue StandardError => e
      if e.respond_to?(:status) && e.status.to_i == 404
        Rails.logger.info("[Evolution] instance already deleted channel=#{id} instance=#{instance_name}")
      else
        Rails.logger.error("[Evolution] delete_instance failed channel=#{id} instance=#{instance_name}: #{e.class} #{e.message}")
      end
    end

    true
  end

  def deletable_instance?
    api_key.present? && instance_name.present?
  end

  def generated_instance_name
    # Gera nome único com:
    # - Timestamp Unix (10 dígitos)
    # - Account ID
    # - Channel ID
    # - Hash randômico (6 caracteres)
    # Exemplo: evo-1704567890-acc5-ch12-a3f8d2

    timestamp = Time.current.to_i

    # Hash único baseado em múltiplos fatores
    unique_hash = Digest::SHA256.hexdigest(
      "#{account_id}-#{id}-#{timestamp}-#{SecureRandom.hex(4)}"
    )[0..5]

    prefix = if Rails.env.development? || Rails.env.test?
               'test-'
             else
               INSTANCE_NAME_PREFIX
             end

    "#{prefix}#{timestamp}-acc#{account_id}-ch#{id}-#{unique_hash}"
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
    host += ":#{uri.port}" if uri.port && [80, 443].exclude?(uri.port)
    host
  rescue URI::InvalidURIError
    nil
  end

  def touch_state_timestamp
    self.state_updated_at = Time.current
  end

  def safe_update_column(attr, value)
    return if value.nil? || self[attr] == value

    update_column(attr, value)
  end

  def log_evo_error(msg, error)
    Rails.logger.error "[EVOLUTION] #{msg} channel=#{id} inbox=#{begin
      inbox_id
    rescue StandardError
      nil
    end}: #{error.class} - #{error.message}"
  end
end
