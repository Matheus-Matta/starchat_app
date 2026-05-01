class ActionCableListener < BaseListener
  include Events::Types

  def notification_created(event)
    notification, account, unread_count, count = extract_notification_and_account(event)
    tokens = [event.data[:notification].user.pubsub_token]
    broadcast(account, tokens, NOTIFICATION_CREATED, { notification: notification.push_event_data, unread_count: unread_count, count: count })
  end

  def notification_updated(event)
    notification, account, unread_count, count = extract_notification_and_account(event)
    tokens = [event.data[:notification].user.pubsub_token]
    broadcast(account, tokens, NOTIFICATION_UPDATED, { notification: notification.push_event_data, unread_count: unread_count, count: count })
  end

  def notification_deleted(event)
    notification_data = event.data[:notification_data]

    user = User.find_by(id: notification_data[:user_id])
    account = Account.find_by(id: notification_data[:account_id])
    return if user.blank? || account.blank?

    notification_finder = NotificationFinder.new(user, account)
    tokens = [user.pubsub_token]
    broadcast(account, tokens, NOTIFICATION_DELETED, {
                notification: { id: notification_data[:id] },
                unread_count: notification_finder.unread_count,
                count: notification_finder.count
              })
  end

  def account_cache_invalidated(event)
    account = event.data[:account]
    tokens = user_tokens(account, account.agents)

    broadcast(account, tokens, ACCOUNT_CACHE_INVALIDATED, {
                cache_keys: event.data[:cache_keys]
              })
  end

  def inbox_member_added(event)
    inbox = event.data[:inbox]
    user  = event.data[:user]
    return unless inbox && user

    account = inbox.account
    broadcast(account, [user.pubsub_token], INBOX_MEMBER_ADDED, { inbox_id: inbox.id })
  end

  def inbox_member_removed(event)
    inbox = event.data[:inbox]
    user  = event.data[:user]
    return unless inbox && user

    account = inbox.account
    broadcast(account, [user.pubsub_token], INBOX_MEMBER_REMOVED, { inbox_id: inbox.id })
  end

  def message_created(event)
    message, account = extract_message_and_account(event)
    conversation = message.conversation
    tokens = restricted_user_tokens(account, conversation) + contact_tokens(conversation.contact_inbox, message)

    broadcast(account, tokens, MESSAGE_CREATED, message.push_event_data)
  end

  def message_updated(event)
    message, account = extract_message_and_account(event)
    conversation = message.conversation
    tokens = restricted_user_tokens(account, conversation) + contact_tokens(conversation.contact_inbox, message)

    broadcast(account, tokens, MESSAGE_UPDATED, message.push_event_data.merge(previous_changes: event.data[:previous_changes]))
  end

  def first_reply_created(event)
    message, account = extract_message_and_account(event)
    conversation = message.conversation
    tokens = restricted_user_tokens(account, conversation)

    broadcast(account, tokens, FIRST_REPLY_CREATED, message.push_event_data)
  end

  def conversation_created(event)
    conversation, account = extract_conversation_and_account(event)
    tokens = restricted_user_tokens(account, conversation) + contact_inbox_tokens(conversation.contact_inbox)

    broadcast(account, tokens, CONVERSATION_CREATED, conversation.push_event_data)
  end

  def conversation_read(event)
    conversation, account = extract_conversation_and_account(event)
    tokens = restricted_user_tokens(account, conversation)

    broadcast(account, tokens, CONVERSATION_READ, conversation.push_event_data)
  end

  def conversation_status_changed(event)
    conversation, account = extract_conversation_and_account(event)
    tokens = restricted_user_tokens(account, conversation) + contact_inbox_tokens(conversation.contact_inbox)

    broadcast(account, tokens, CONVERSATION_STATUS_CHANGED, conversation.push_event_data)
  end

  def conversation_updated(event)
    conversation, account = extract_conversation_and_account(event)
    tokens = restricted_user_tokens(account, conversation) + contact_inbox_tokens(conversation.contact_inbox)

    broadcast(account, tokens, CONVERSATION_UPDATED, conversation.push_event_data)
  end

  def conversation_typing_on(event)
    conversation = event.data[:conversation]
    account = conversation.account
    user = event.data[:user]
    tokens = typing_event_listener_tokens(account, conversation, user)

    broadcast(
      account,
      tokens,
      CONVERSATION_TYPING_ON,
      conversation: conversation.push_event_data,
      user: user.push_event_data,
      is_private: event.data[:is_private] || false
    )
  end

  def conversation_typing_off(event)
    conversation = event.data[:conversation]
    account = conversation.account
    user = event.data[:user]
    tokens = typing_event_listener_tokens(account, conversation, user)

    broadcast(
      account,
      tokens,
      CONVERSATION_TYPING_OFF,
      conversation: conversation.push_event_data,
      user: user.push_event_data,
      is_private: event.data[:is_private] || false
    )
  end

  def assignee_changed(event)
    conversation, account = extract_conversation_and_account(event)
    tokens = restricted_user_tokens(account, conversation)

    broadcast(account, tokens, ASSIGNEE_CHANGED, conversation.push_event_data)
  end

  def team_changed(event)
    conversation, account = extract_conversation_and_account(event)
    tokens = restricted_user_tokens(account, conversation)

    broadcast(account, tokens, TEAM_CHANGED, conversation.push_event_data)
  end

  def conversation_contact_changed(event)
    conversation, account = extract_conversation_and_account(event)
    tokens = restricted_user_tokens(account, conversation)

    broadcast(account, tokens, CONVERSATION_CONTACT_CHANGED, conversation.push_event_data)
  end

  def contact_created(event)
    contact, account = extract_contact_and_account(event)
    broadcast(account, [account_token(account)], CONTACT_CREATED, contact.push_event_data)
  end

  def contact_updated(event)
    contact, account = extract_contact_and_account(event)
    broadcast(account, [account_token(account)], CONTACT_UPDATED, contact.push_event_data)
  end

  def contact_merged(event)
    contact, account = extract_contact_and_account(event)
    broadcast(account, [account_token(account)], CONTACT_MERGED, contact.push_event_data)
  end

  def contact_deleted(event)
    contact_data = event.data[:contact_data]
    account = Account.find_by(id: contact_data[:account_id])
    return if account.blank?

    broadcast(account, [account_token(account)], CONTACT_DELETED, contact_data)
  end

  def conversation_mentioned(event)
    conversation, account = extract_conversation_and_account(event)
    user = event.data[:user]

    broadcast(account, [user.pubsub_token], CONVERSATION_MENTIONED, conversation.push_event_data)
  end

  def conversation_participant_added(event)
    conversation, account = extract_conversation_and_account(event)
    user = event.data[:user]
    return unless user

    broadcast(account, [user.pubsub_token], CONVERSATION_PARTICIPANT_ADDED, conversation.push_event_data)
  end

  def conversation_participant_removed(event)
    conversation, account = extract_conversation_and_account(event)
    user = event.data[:user]
    return unless user

    broadcast(account, [user.pubsub_token], CONVERSATION_PARTICIPANT_REMOVED, { id: conversation.display_id })
  end

  private

  def account_token(account)
    "account_#{account.id}"
  end

  def typing_event_listener_tokens(account, conversation, user)
    current_user_token = user.is_a?(Contact) ? conversation.contact_inbox.pubsub_token : user.pubsub_token
    (restricted_user_tokens(account, conversation) + [conversation.contact_inbox.pubsub_token]) - [current_user_token]
  end

  def user_tokens(account, agents)
    agent_tokens = agents.pluck(:pubsub_token)
    admin_tokens = account.administrators.pluck(:pubsub_token)
    (agent_tokens + admin_tokens).uniq
  end

  def restricted_user_tokens(account, conversation)
    admin_tokens = account.administrators.pluck(:pubsub_token)

    inbox_members = conversation.inbox.members.includes(:teams, account_users: :custom_role)
                                .where(account_users: { account_id: account.id })

    allowed_agent_tokens = []

    inbox_members.find_each do |user|
      account_user = user.account_users.find { |au| au.account_id == account.id }
      next unless account_user

      # Admins are already handled
      next if account_user.administrator?

      # Agents without custom roles have full access to inbox conversations by default
      if account_user.custom_role_id.nil?
        allowed_agent_tokens << user.pubsub_token
        next
      end

      permissions = account_user.custom_role.permissions

      if permissions.include?('conversation_manage')
        allowed_agent_tokens << user.pubsub_token
        next
      end

      # Check if user is the assignee
      if conversation.assignee_id == user.id &&
         (permissions.include?('conversation_participating_manage') ||
          permissions.include?('conversation_team_manage') ||
          permissions.include?('conversation_unassigned_manage'))
        allowed_agent_tokens << user.pubsub_token
        next
      end

      if conversation.assignee_id.nil? && permissions.include?('conversation_unassigned_manage')
        allowed_agent_tokens << user.pubsub_token
        next
      end

      if conversation.team_id.present? &&
         permissions.include?('conversation_team_manage') &&
         user.teams.any? { |team| team.id == conversation.team_id }
        # Use existing loaded association to avoid N+1 and potential cache issues
        allowed_agent_tokens << user.pubsub_token
        next
      end
    end

    # Explicitly include conversation participants who may not be inbox members
    participant_tokens = conversation.conversation_participants
                                     .joins(:user)
                                     .where.not(user_id: account.administrators.select(:id))
                                     .pluck('users.pubsub_token')

    (allowed_agent_tokens + admin_tokens + participant_tokens).uniq
  end

  def contact_tokens(contact_inbox, message)
    return [] if message.private?
    return [] if message.activity?
    return [] if contact_inbox.nil?

    contact_inbox_tokens(contact_inbox)
  end

  def contact_inbox_tokens(contact_inbox)
    contact = contact_inbox.contact

    contact_inbox.hmac_verified? ? contact.contact_inboxes.where(hmac_verified: true).filter_map(&:pubsub_token) : [contact_inbox.pubsub_token]
  end

  def broadcast(account, tokens, event_name, data)
    return if tokens.blank?

    payload = data.merge(account_id: account.id)
    # So the frondend knows who performed the action.
    # Useful in cases like conversation assignment for generating a notification with assigner name.
    payload[:performer] = Current.user&.push_event_data if Current.user.present?

    ::ActionCableBroadcastJob.perform_later(tokens.uniq, event_name, payload)
  end
end

ActionCableListener.prepend_mod_with('ActionCableListener')
