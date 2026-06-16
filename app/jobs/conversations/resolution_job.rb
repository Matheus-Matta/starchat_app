class Conversations::ResolutionJob < ApplicationJob
  queue_as :low

  def perform(account:, inbox: nil)
    inbox ? resolve_for_inbox(inbox) : resolve_all_for_account(account)
  end

  private

  # ── Account-wide pass ────────────────────────────────────────────────────────

  def resolve_all_for_account(account)
    policy_inbox_ids = account.inboxes
      .joins('LEFT JOIN inbox_conversation_flows icf ON icf.inbox_id = inboxes.id')
      .where('inboxes.auto_resolve_duration IS NOT NULL OR icf.id IS NOT NULL')
      .pluck(:id)

    Inbox.includes(:inbox_conversation_flow, :conversation_flow)
         .where(id: policy_inbox_ids)
         .each { |inbox| resolve_for_inbox(inbox) }

    resolve_global_for_account(account, exclude_inbox_ids: policy_inbox_ids)
  end

  # ── Per-inbox dispatch ────────────────────────────────────────────────────────

  def resolve_for_inbox(inbox)
    if inbox.conversation_flow.present?
      flow = inbox.active_conversation_flow
      return unless flow

      resolve_with_flow(inbox, flow)
    else
      resolve_with_inbox_settings(inbox)
    end
  end

  def resolve_with_flow(inbox, flow)
    return unless flow.auto_resolve_active?

    scope = resolvable_scope(inbox.conversations, ignore_waiting: flow.auto_resolve_ignore_waiting, duration: flow.auto_resolve_duration)
    process_conversations(scope, tag: 'flow') do |conversation|
      send_resolve_message(conversation, flow.auto_resolve_message)
      apply_dual_label(conversation, flow)
      conversation.toggle_status
    end
  end

  def resolve_with_inbox_settings(inbox)
    duration = inbox.effective_auto_resolve_duration
    return unless duration.to_i.positive?

    scope = resolvable_scope(inbox.conversations, ignore_waiting: inbox.effective_auto_resolve_ignore_waiting, duration: duration)
    process_conversations(scope, tag: 'inbox') do |conversation|
      msg = inbox.effective_auto_resolve_message
      ::MessageTemplates::Template::AutoResolve.new(conversation: conversation).perform if msg.present?
      label = inbox.effective_auto_resolve_label
      conversation.add_labels(label) if label.present?
      conversation.toggle_status
    end
  end

  def resolve_global_for_account(account, exclude_inbox_ids: [])
    return unless account.auto_resolve_after.to_i.positive?

    base  = account.conversations.where.not(inbox_id: exclude_inbox_ids)
    scope = resolvable_scope(base, ignore_waiting: account.auto_resolve_ignore_waiting, duration: account.auto_resolve_after)
    process_conversations(scope, tag: 'global') do |conversation|
      ::MessageTemplates::Template::AutoResolve.new(conversation: conversation).perform if account.auto_resolve_message.present?
      conversation.add_labels(account.auto_resolve_label) if account.auto_resolve_label.present?
      conversation.toggle_status
    end
  end

  # ── Helpers ──────────────────────────────────────────────────────────────────

  def resolvable_scope(source, ignore_waiting:, duration:)
    if ignore_waiting
      source.resolvable_not_waiting(duration)
    else
      source.resolvable_all(duration)
    end
  end

  def process_conversations(scope, tag:, &block)
    scope.find_in_batches(batch_size: 100) do |batch|
      batch.each do |conversation|
        block.call(conversation)
      rescue StandardError => e
        Rails.logger.error "ResolutionJob[#{tag}] conv=#{conversation.id}: #{e.message}"
      end
    end
  end

  def send_resolve_message(conversation, message)
    return if message.blank? || !conversation.can_reply?

    conversation.messages.create!(
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      message_type: :template,
      content: message
    )
  end

  def apply_dual_label(conversation, flow)
    label = flow.interaction_label_for(conversation)
    conversation.add_labels(label) if label.present?
  end
end
