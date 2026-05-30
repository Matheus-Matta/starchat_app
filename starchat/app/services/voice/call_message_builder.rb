class Voice::CallMessageBuilder
  def self.perform!(conversation:, direction:, payload:, timestamps:)
    new(conversation: conversation, direction: direction, payload: payload, timestamps: timestamps).perform!
  end

  def initialize(conversation:, direction:, payload:, timestamps:)
    @conversation = conversation
    @direction = direction
    @payload = payload
    @timestamps = timestamps
  end

  def perform!
    message = find_existing_message || build_new_message
    message.content_attributes = { 'data' => build_data }
    message.save!
    message
  end

  private

  def find_existing_message
    @conversation.messages.voice_calls.last
  end

  def build_new_message
    @conversation.messages.build(
      message_type: @direction == 'inbound' ? :incoming : :outgoing,
      account_id: @conversation.account_id,
      inbox_id: @conversation.inbox_id,
      sender: @conversation.contact,
      content_type: :voice_call
    )
  end

  def build_data
    @payload.stringify_keys.merge(
      'call_direction' => @direction,
      'meta' => @timestamps.stringify_keys.transform_values(&:to_i)
    )
  end
end
