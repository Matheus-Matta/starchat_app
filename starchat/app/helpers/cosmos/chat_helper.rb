module Cosmos::ChatHelper
  def request_chat_completion
    log_chat_completion_request
    chat = build_chat

    add_messages_to_chat(chat)
    with_agent_session do
      last_content = conversation_messages.last[:content]
      text, attachments = Cosmos::OpenAiMessageBuilderService.extract_text_and_attachments(last_content)

      response = attachments.any? ? chat.ask(text, with: attachments) : chat.ask(text)
      build_response(response)
    end
  rescue StandardError => e
    Rails.logger.error "#{self.class.name} Assistant: #{@assistant.id}, Error in chat completion: #{e}"
    raise e
  end

  private

  def build_chat
    llm_chat = chat(model: @model, temperature: temperature)
    llm_chat = llm_chat.with_params(response_format: { type: 'json_object' })

    llm_chat = setup_tools(llm_chat)
    llm_chat = setup_system_instructions(llm_chat)
    setup_event_handlers(llm_chat)
  end

  def setup_tools(llm_chat)
    @tools&.each do |tool|
      llm_chat = llm_chat.with_tool(tool)
    end
    llm_chat
  end

  def setup_system_instructions(chat)
    system_messages = @messages.select { |m| m[:role] == 'system' || m[:role] == :system }
    combined_instructions = system_messages.pluck(:content).join("\n\n")
    chat.with_instructions(combined_instructions)
  end

  def setup_event_handlers(chat)
    # NOTE: We only use on_end_message to record the generation with token counts.
    # RubyLLM callbacks fire after chunks arrive, not around the API call, so
    # span timing won't reflect actual API latency. But Langfuse calculates costs
    # from model + token counts, so this is sufficient for cost tracking.
    chat.on_end_message { |message| record_llm_generation(chat, message) }
    chat.on_tool_call { |tool_call| handle_tool_call(tool_call) }
    chat.on_tool_result { |result| handle_tool_result(result) }
    chat
  end

  def handle_tool_call(tool_call)
    persist_thinking_message(tool_call)
    start_tool_span(tool_call)
    (@pending_tool_calls ||= []).push(tool_call)
  end

  def handle_tool_result(result)
    end_tool_span(result)
    persist_tool_completion
  end

  def add_messages_to_chat(chat)
    conversation_messages[0...-1].each do |msg|
      text, attachments = Cosmos::OpenAiMessageBuilderService.extract_text_and_attachments(msg[:content])
      content = attachments.any? ? RubyLLM::Content.new(text, attachments) : text
      chat.add_message(role: msg[:role].to_sym, content: content)
    end
  end

  def process_tool_calls(tool_calls)
    append_tool_calls(tool_calls)
    tool_calls.each do |tool_call|
      process_tool_call(tool_call)
    end
    request_chat_completion
  end

  def process_tool_call(tool_call)
    arguments = JSON.parse(tool_call['function']['arguments'])
    function_name = tool_call['function']['name']
    tool_call_id = tool_call['id']

    if @tool_registry.respond_to?(function_name)
      execute_tool(function_name, arguments, tool_call_id)
    else
      process_invalid_tool_call(function_name, tool_call_id)
    end
  end

  def execute_tool(function_name, arguments, tool_call_id)
    persist_message(
      {
        content: I18n.t('cosmos.copilot.using_tool', function_name: function_name),
        function_name: function_name
      },
      'assistant_thinking'
    )
    result = @tool_registry.send(function_name, arguments)
    persist_message(
      {
        content: I18n.t('cosmos.copilot.completed_tool_call', function_name: function_name),
        function_name: function_name
      },
      'assistant_thinking'
    )
    append_tool_response(result, tool_call_id)
  end

  def append_tool_calls(tool_calls)
    @messages << {
      role: 'assistant',
      tool_calls: tool_calls
    }
  end

  def process_invalid_tool_call(function_name, tool_call_id)
    persist_message({ content: I18n.t('cosmos.copilot.invalid_tool_call'), function_name: function_name }, 'assistant_thinking')
    append_tool_response(I18n.t('cosmos.copilot.tool_not_available'), tool_call_id)
  end

  def temperature
    @assistant&.config&.[]('temperature').to_f || 1
  end

  def resolved_account_id
    @account&.id || @assistant&.account_id
  end

  def resolved_channel_type
    @conversation&.inbox&.channel_type
  end

  # Ensures all LLM calls and tool executions within an agentic loop
  # are grouped under a single trace/session in Langfuse.
  #
  # Without this guard, each recursive call to request_chat_completion
  # (triggered by tool calls) would create a separate trace instead of
  # nesting within the existing session span.
  def with_agent_session(&)
    already_active = @agent_session_active
    return yield if already_active

    @agent_session_active = true
    instrument_agent_session(instrumentation_params, &)
  ensure
    @agent_session_active = false unless already_active
  end

  def conversation_messages
    @messages
  end

  # Must be implemented by including class to identify the feature for instrumentation.
  # Used for Langfuse tagging and span naming.
  def feature_name
    raise NotImplementedError, "#{self.class.name} must implement #feature_name"
  end

  def log_chat_completion_request
    Rails.logger.info("#{self.class.name} Assistant: #{@assistant.id}, requesting completion for #{@messages} with #{@tools&.length || 0} tools")
  end
end
