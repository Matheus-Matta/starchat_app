class MessageTemplates::Template::Reengagement
  pattr_initialize [:conversation!, :message!]

  def perform
    return if message.blank?

    if conversation.can_reply?
      conversation.messages.create!(reengagement_message_params)
    else
      create_not_sent_activity_message
    end
  end

  private

  def create_not_sent_activity_message
    content = I18n.t('conversations.activity.reengagement.not_sent_due_to_messaging_window')
    return unless content

    activity_message_params = {
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      message_type: :activity,
      content: content
    }
    ::Conversations::ActivityMessageJob.perform_later(conversation, activity_message_params)
  end

  def reengagement_message_params
    {
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      message_type: :template,
      content: message
    }
  end
end
