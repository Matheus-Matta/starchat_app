class Conversations::ResolutionJob < ApplicationJob
  queue_as :low

  # Pode ser chamado:
  #   perform(account: account)           => usa config global da conta (compatível com código antigo)
  #   perform(account: account, inbox: i) => usa config efetiva do inbox (prioridade inbox > conta)
  def perform(account:, inbox: nil)
    if inbox
      resolve_for_inbox(inbox)
    else
      resolve_for_account(account)
    end
  end

  private

  def resolve_for_inbox(inbox)
    duration = inbox.effective_auto_resolve_duration
    return unless duration.to_i.positive?

    ignore_waiting = inbox.effective_auto_resolve_ignore_waiting
    conversations = if ignore_waiting
                      inbox.conversations.resolvable_not_waiting(duration).limit(Limits::BULK_ACTIONS_LIMIT)
                    else
                      inbox.conversations.resolvable_all(duration).limit(Limits::BULK_ACTIONS_LIMIT)
                    end

    conversations.each do |conversation|
      msg = inbox.effective_auto_resolve_message
      ::MessageTemplates::Template::AutoResolve.new(conversation: conversation).perform if msg.present?
      label = inbox.effective_auto_resolve_label
      conversation.add_labels(label) if label.present?
      conversation.toggle_status
    end
  end

  def resolve_for_account(account)
    conversations = conversation_scope(account).limit(Limits::BULK_ACTIONS_LIMIT)
    conversations.each do |conversation|
      ::MessageTemplates::Template::AutoResolve.new(conversation: conversation).perform if account.auto_resolve_message.present?
      conversation.add_labels(account.auto_resolve_label) if account.auto_resolve_label.present?
      conversation.toggle_status
    end
  end

  def conversation_scope(account)
    inboxes_with_custom_rule = account.inboxes.with_inbox_auto_resolve.select(:id)
    scope = account.conversations.where.not(inbox_id: inboxes_with_custom_rule)

    if account.auto_resolve_ignore_waiting
      scope.resolvable_not_waiting(account.auto_resolve_after)
    else
      scope.resolvable_all(account.auto_resolve_after)
    end
  end
end
