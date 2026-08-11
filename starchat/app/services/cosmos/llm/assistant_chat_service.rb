require 'openai'

class Cosmos::Llm::AssistantChatService < Llm::BaseOpenAiService
  include Cosmos::ChatHelper

  def initialize(assistant: nil)
    super()
  end

  def initialize(assistant: nil, conversation: nil, source: nil)
    super()

    @assistant = assistant
    @messages = [system_message]
    @response = ''
    register_tools
  end

  # additional_message: A single message (String) from the user that should be appended to the chat.
  #                    It can be an empty String or nil when you only want to supply historical messages.
  # message_history:   An Array of already formatted messages that provide the previous context.
  # role:              The role for the additional_message (defaults to `user`).
  #
  # NOTE: Parameters are provided as keyword arguments to improve clarity and avoid relying on
  # positional ordering.
  def generate_response(additional_message: nil, message_history: [], role: 'user')
    @messages += message_history
    @messages << { role: role, content: additional_message } if additional_message.present?
    request_chat_completion
  end

  private

  def register_tools
    @tool_registry = Cosmos::ToolRegistryService.new(@assistant, user: nil)
    @tool_registry.register_tool(Cosmos::Tools::SearchDocumentationService)
  end

  def system_message
    {
      role: 'system',
      content: Cosmos::Llm::SystemPromptsService.assistant_response_generator(@assistant.name, @assistant.config['product_name'], @assistant.config)
    }
  end

  def persist_message(message, message_type = 'assistant')
    # No need to implement
  end
end
