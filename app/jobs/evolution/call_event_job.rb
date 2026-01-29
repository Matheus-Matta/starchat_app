class Evolution::CallEventJob < ApplicationJob
  include Evolution::CommonHelpers

  queue_as :default

  def perform(inbox_id, event_data)
    @inbox = Inbox.find_by(id: inbox_id)
    return unless @inbox

    status = event_data['status']
    # user only wants notification for 'offer' (receiving call)
    return unless status == 'offer'

    from = event_data['from'] || event_data['chatId']
    
    Rails.logger.info("[Evolution] Call Event (Offer): from=#{from} (Inbox##{inbox_id}). Triggering notification.")
    create_incoming_call_notification(@inbox, from)
  end
end
