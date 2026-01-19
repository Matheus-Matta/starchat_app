# app/controllers/api/v1/integrations/evolution_controller.rb
class Api::V1::Integrations::EvolutionController < ActionController::API
  before_action :load_inbox_and_channel
  before_action :verify_signature!, only: [:webhook]

  def webhook
    case params[:event] || request.headers['x-evo-event']
    when 'QRCODE_UPDATED'
      WizardBroadcaster.broadcast_qr(@inbox, params[:qrcode_base64])
    when 'MESSAGES_UPSERT'
      upsert_messages(params[:messages])
    when 'MESSAGES_UPDATE'
      update_status(params[:updates])
    when 'CONNECTION_UPDATE'
      ChannelStatusUpdater.perform_async(@inbox.id, params[:state])
    end
    head :ok
  end

  private

  def load_inbox_and_channel
    @inbox = Inbox.find(params[:inbox_id])
    @channel = @inbox.channel
  end

  def verify_signature!; end

  def upsert_messages(msgs)
    Array(msgs).each do |m|
      number = extract_msisdn(m)
      contact = ContactInboxBuilder.new(@inbox, number).perform
      MessageBuilder.new(@inbox, contact, m).incoming!.save!
    end
  end

  def update_status(updates); end
end
