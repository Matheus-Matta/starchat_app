module Starchat::MessageTemplates::HookExecutionService
  MAX_ATTACHMENT_WAIT_SECONDS = 4

  private

  def trigger_templates
    ::MessageTemplates::Template::OutOfOffice.new(conversation: conversation).perform if should_send_out_of_office_message?
    ::MessageTemplates::Template::Greeting.new(conversation: conversation).perform if should_send_greeting?
    ::MessageTemplates::Template::EmailCollect.new(conversation: conversation).perform if inbox.enable_email_collect && should_send_email_collect?

    return unless should_process_cosmos_response?

    unless inbox.cosmos_active?
      Rails.logger.info "[Cosmos] Inbox #{inbox.id} not active. Handoff."
      return perform_handoff
    end

    Rails.logger.info "[Cosmos] Scheduling response for conv #{conversation.id}" if Rails.env.development?
    schedule_cosmos_response
  end

  def schedule_cosmos_response
    job_args = [conversation, conversation.inbox.cosmos_assistant]

    if message.attachments.blank?
      Cosmos::Conversation::ResponseBuilderJob.perform_later(*job_args)
    else
      wait_time = calculate_attachment_wait_time
      Cosmos::Conversation::ResponseBuilderJob.set(wait: wait_time).perform_later(*job_args)
    end
  end

  def calculate_attachment_wait_time
    attachment_count = message.attachments.size
    base_wait = 1.second
    additional_wait = [attachment_count * 1, MAX_ATTACHMENT_WAIT_SECONDS].min.seconds
    base_wait + additional_wait
  end

  def should_process_cosmos_response?
    # Logic:
    # 1. Incoming message
    # 2. Assistant present
    # 3. Conversation must be Pending (Standard behavior)

    is_incoming = message.incoming?
    has_assistant = inbox.cosmos_assistant.present?
    is_pending = conversation.pending?

    is_pending && is_incoming && has_assistant
  end

  def perform_handoff
    return unless conversation.pending?

    Rails.logger.info("Cosmos limit exceeded handoff: #{conversation.id}")
    conversation.messages.create!(
      message_type: :outgoing,
      account_id: conversation.account.id,
      inbox_id: conversation.inbox.id,
      content: 'Transferring to another agent due to limit.'
    )
    conversation.bot_handoff!
  end
end
