class AgentNotifications::ConversationNotificationsMailer < ApplicationMailer
  def conversation_creation(conversation, agent, _user)
    return unless smtp_config_set_or_development?

    @agent = agent
    @conversation = conversation
    inbox_name = @conversation.inbox&.sanitized_name
    subject = I18n.t('notifications.email_subject.conversation_creation',
                     agent_name: @agent.available_name,
                     display_id: @conversation.display_id,
                     inbox_name: inbox_name)
    @action_url = app_account_conversation_url(account_id: @conversation.account_id, id: @conversation.display_id)
    send_mail_with_liquid(to: @agent.email, subject: subject) and return
  end

  def conversation_assignment(conversation, agent, _user)
    return unless smtp_config_set_or_development?

    @agent = agent
    @conversation = conversation
    subject = I18n.t('notifications.email_subject.conversation_assignment',
                     agent_name: @agent.available_name,
                     display_id: @conversation.display_id)
    @action_url = app_account_conversation_url(account_id: @conversation.account_id, id: @conversation.display_id)
    send_mail_with_liquid(to: @agent.email, subject: subject) and return
  end

  def conversation_mention(conversation, agent, message)
    return unless smtp_config_set_or_development?

    @agent = agent
    @conversation = conversation
    @message = message
    subject = I18n.t('notifications.email_subject.conversation_mention',
                     agent_name: @agent.available_name,
                     display_id: @conversation.display_id)
    @action_url = app_account_conversation_url(account_id: @conversation.account_id, id: @conversation.display_id)
    send_mail_with_liquid(to: @agent.email, subject: subject) and return
  end

  def assigned_conversation_new_message(conversation, agent, message)
    return unless smtp_config_set_or_development?
    # Don't spam with email notifications if agent is online
    return if ::OnlineStatusTracker.get_presence(message.account_id, 'User', agent.id)

    @agent = agent
    @conversation = conversation
    subject = I18n.t('notifications.email_subject.assigned_conversation_new_message',
                     agent_name: @agent.available_name,
                     display_id: @conversation.display_id)
    @action_url = app_account_conversation_url(account_id: @conversation.account_id, id: @conversation.display_id)
    send_mail_with_liquid(to: @agent.email, subject: subject) and return
  end

  def participating_conversation_new_message(conversation, agent, message)
    return unless smtp_config_set_or_development?
    # Don't spam with email notifications if agent is online
    return if ::OnlineStatusTracker.get_presence(message.account_id, 'User', agent.id)

    @agent = agent
    @conversation = conversation
    subject = I18n.t('notifications.email_subject.participating_conversation_new_message',
                     agent_name: @agent.available_name,
                     display_id: @conversation.display_id)
    @action_url = app_account_conversation_url(account_id: @conversation.account_id, id: @conversation.display_id)
    send_mail_with_liquid(to: @agent.email, subject: subject) and return
  end

  def inbox_connection_update(inbox, agent, _secondary)
    return unless smtp_config_set_or_development?

    @agent = agent
    @inbox = inbox
    subject = I18n.t('notifications.email_subject.inbox_connection_update',
                     agent_name: @agent.available_name,
                     inbox_name: @inbox.sanitized_name)
    @action_url = "#{ENV['FRONTEND_URL']}/app/accounts/#{@inbox.account_id}/settings/inboxes/#{@inbox.id}"
    send_mail_with_liquid(to: @agent.email, subject: subject) and return
  end

  private

  def liquid_droppables
    super.merge({
                  user: @agent,
                  conversation: @conversation,
                  inbox: @inbox || @conversation&.inbox,
                  message: @message
                })
  end
end

AgentNotifications::ConversationNotificationsMailer.prepend_mod_with('AgentNotifications::ConversationNotificationsMailer')
