# Migrates an inbox from an unofficial Evolution (Baileys) channel to the
# official WhatsApp Cloud API, keeping the same inbox_id so conversations,
# messages and contact_inboxes survive the switch untouched.
#
# Credentials come from one of two paths:
#   * manual   - the admin pastes api_key / phone_number_id / business_account_id
#   * embedded - an Embedded Signup authorization code, which we trade for a
#                token so no credential ever has to be typed by hand
class Evolution::MigrateToWhatsappService
  Result = Struct.new(:inbox, :whatsapp_channel, :needs_reauthorization, keyword_init: true)

  def initialize(evolution_channel:, whatsapp_params:)
    @evolution_channel = evolution_channel
    @whatsapp_params = whatsapp_params.to_h.symbolize_keys
  end

  def perform
    inbox = find_inbox!
    attributes = channel_attributes
    whatsapp_channel = nil

    ActiveRecord::Base.transaction do
      whatsapp_channel = Channel::Whatsapp.create!(
        account: @evolution_channel.account,
        phone_number: attributes[:phone_number],
        provider: 'whatsapp_cloud',
        provider_config: attributes[:provider_config]
      )

      inbox.update!(channel: whatsapp_channel)
    end

    # Channel::Whatsapp#should_auto_setup_webhooks? deliberately skips the
    # `after_commit :setup_webhooks` callback for embedded_signup channels, so
    # the embedded path has to register them itself.
    whatsapp_channel.setup_webhooks if embedded_signup?

    # Either the callback above or the explicit call already ran synchronously by
    # this point, so reauthorization_required? reflects whether it succeeded.
    needs_reauth = whatsapp_channel.reauthorization_required?
    disconnect_old_instance! unless needs_reauth

    Result.new(inbox: inbox.reload, whatsapp_channel: whatsapp_channel, needs_reauthorization: needs_reauth)
  end

  private

  def embedded_signup?
    @whatsapp_params[:code].present?
  end

  def channel_attributes
    embedded_signup? ? embedded_signup_attributes : manual_attributes
  end

  def manual_attributes
    {
      phone_number: @whatsapp_params[:phone_number],
      provider_config: {
        'api_key' => @whatsapp_params[:api_key],
        'phone_number_id' => @whatsapp_params[:phone_number_id],
        'business_account_id' => @whatsapp_params[:business_account_id]
      }
    }
  end

  # Mirrors Whatsapp::EmbeddedSignupService's credential resolution. We can't reuse
  # that service directly because it creates its own inbox, and the whole point of
  # a migration is to keep the existing one.
  def embedded_signup_attributes
    validate_embedded_signup_params!

    waba_id = @whatsapp_params[:waba_id]
    access_token = Whatsapp::TokenExchangeService.new(@whatsapp_params[:code]).perform
    phone_info = Whatsapp::PhoneInfoService.new(waba_id, @whatsapp_params[:phone_number_id], access_token).perform
    Whatsapp::TokenValidationService.new(access_token, waba_id).perform

    {
      phone_number: phone_info[:phone_number],
      provider_config: {
        'api_key' => access_token,
        'phone_number_id' => phone_info[:phone_number_id],
        'business_account_id' => waba_id,
        'source' => 'embedded_signup'
      }
    }
  end

  def validate_embedded_signup_params!
    missing_params = %i[code business_id waba_id].select { |key| @whatsapp_params[key].blank? }
    return if missing_params.empty?

    raise ArgumentError, "Required parameters are missing: #{missing_params.join(', ')}"
  end

  def find_inbox!
    Inbox.find_by!(
      account_id: @evolution_channel.account_id,
      channel_id: @evolution_channel.id,
      channel_type: 'Channel::Evolution'
    )
  end

  # Keeping the old Evolution instance alive when reauthorization is required
  # avoids leaving the customer with no working WhatsApp channel at all.
  def disconnect_old_instance!
    @evolution_channel.destroy
  rescue StandardError => e
    Rails.logger.error(
      "[Evolution] cleanup after migration failed channel=#{@evolution_channel.id}: #{e.class} #{e.message}"
    )
  end
end
