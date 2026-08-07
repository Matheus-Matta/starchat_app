# Migrates an inbox from an unofficial Evolution (Baileys) channel to the
# official WhatsApp Cloud API, keeping the same inbox_id so conversations,
# messages and contact_inboxes survive the switch untouched.
class Evolution::MigrateToWhatsappService
  Result = Struct.new(:inbox, :whatsapp_channel, :needs_reauthorization, keyword_init: true)

  def initialize(evolution_channel:, whatsapp_params:)
    @evolution_channel = evolution_channel
    @whatsapp_params = whatsapp_params
  end

  def perform
    inbox = find_inbox!
    whatsapp_channel = nil

    ActiveRecord::Base.transaction do
      whatsapp_channel = Channel::Whatsapp.create!(
        account: @evolution_channel.account,
        phone_number: @whatsapp_params[:phone_number],
        provider: 'whatsapp_cloud',
        provider_config: {
          'api_key' => @whatsapp_params[:api_key],
          'phone_number_id' => @whatsapp_params[:phone_number_id],
          'business_account_id' => @whatsapp_params[:business_account_id]
        }
      )

      inbox.update!(channel: whatsapp_channel)
    end

    # `after_commit :setup_webhooks` on Channel::Whatsapp already ran synchronously
    # by this point, so reauthorization_required? reflects whether it succeeded.
    needs_reauth = whatsapp_channel.reauthorization_required?
    disconnect_old_instance! unless needs_reauth

    Result.new(inbox: inbox.reload, whatsapp_channel: whatsapp_channel, needs_reauthorization: needs_reauth)
  end

  private

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
