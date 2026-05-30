class Cosmos::InboxPendingConversationsResolutionJob < ApplicationJob
  queue_as :low

  def perform(inbox)
    Current.executed_by = inbox.cosmos_assistant

    resolvable_conversations = inbox.conversations.pending.where('last_activity_at < ? ',
                                                                 Time.now.utc - 1.hour).limit(Limits::BULK_ACTIONS_LIMIT)
    resolvable_conversations.each do |conversation|
      create_resolution_message(conversation, inbox)
      conversation.resolved!
    end
  ensure
    Current.reset
  end

  private

  def evaluate_conversation_completion?(account)
    account.feature_enabled?('cosmos_tasks') && account.cosmos_auto_resolve_evaluated?
  end

  def perform_time_based(inbox)
    Current.executed_by = inbox.cosmos_assistant

    resolvable_pending_conversations(inbox).each do |conversation|
      create_resolution_message(conversation, inbox)
      conversation.resolved!
    end
  end

  def perform_with_evaluation(inbox)
    Current.executed_by = inbox.cosmos_assistant

    resolvable_pending_conversations(inbox).each do |conversation|
      evaluation = evaluate_conversation(conversation, inbox)
      next unless still_resolvable_after_evaluation?(conversation)

      if evaluation[:complete]
        resolve_conversation(conversation, inbox, evaluation[:reason])
      else
        handoff_conversation(conversation, inbox, evaluation[:reason])
      end
    end
  end

  def evaluate_conversation(conversation, inbox)
    Cosmos::ConversationCompletionService.new(
      account: inbox.account,
      conversation_display_id: conversation.display_id
    ).perform
  end

  def resolvable_pending_conversations(inbox)
    inbox.conversations.pending
         .where('last_activity_at < ?', auto_resolve_cutoff_time)
         .limit(Limits::BULK_ACTIONS_LIMIT)
  end

  def still_resolvable_after_evaluation?(conversation)
    conversation.reload
    conversation.pending? && conversation.last_activity_at < auto_resolve_cutoff_time
  rescue ActiveRecord::RecordNotFound
    false
  end

  def auto_resolve_cutoff_time
    Time.now.utc - 1.hour
  end

  def resolve_conversation(conversation, inbox, reason)
    create_private_note(conversation, inbox, "Auto-resolved: #{reason}")
    create_resolution_message(conversation, inbox)
    conversation.with_cosmos_activity_context(
      reason: COSMOS_INFERENCE_RESOLVE_ACTIVITY_REASON,
      reason_type: :inference
    ) { conversation.resolved! }
    conversation.dispatch_cosmos_inference_resolved_event
  end

  def handoff_conversation(conversation, inbox, reason)
    create_private_note(conversation, inbox, "Auto-handoff: #{reason}")
    create_handoff_message(conversation, inbox)
    conversation.with_cosmos_activity_context(
      reason: COSMOS_INFERENCE_HANDOFF_ACTIVITY_REASON,
      reason_type: :inference
    ) { conversation.bot_handoff! }
    conversation.dispatch_cosmos_inference_handoff_event
    send_out_of_office_message_if_applicable(conversation.reload)
  end

  def send_out_of_office_message_if_applicable(conversation)
    # Campaign conversations should never receive OOO templates — the campaign itself
    # serves as the initial outreach, and OOO would be confusing in that context.
    return if conversation.campaign.present?

    ::MessageTemplates::Template::OutOfOffice.perform_if_applicable(conversation)
  end

  def create_private_note(conversation, inbox, content)
    conversation.messages.create!(
      message_type: :outgoing,
      private: true,
      sender: inbox.cosmos_assistant,
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      content: content
    )
  end

  def create_resolution_message(conversation, inbox)
    I18n.with_locale(inbox.account.locale) do
      resolution_message = inbox.cosmos_assistant.config['resolution_message']
      conversation.messages.create!(
        {
          message_type: :outgoing,
          account_id: conversation.account_id,
          inbox_id: conversation.inbox_id,
          content: resolution_message.presence || I18n.t('conversations.activity.auto_resolution_message'),
          sender: inbox.cosmos_assistant
        }
      )
    end
  end

  def create_handoff_message(conversation, inbox)
    handoff_message = inbox.cosmos_assistant.config['handoff_message']
    return if handoff_message.blank?

    conversation.messages.create!(
      message_type: :outgoing,
      sender: inbox.cosmos_assistant,
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      content: handoff_message,
      preserve_waiting_since: true
    )
  end
end
