module Voice
  module CallStatus
    class Manager
      def initialize(conversation:, call_sid:)
        @conversation = conversation
        @call_sid = call_sid
      end

      def process_status_update(status, duration: nil, timestamp: nil)
        update_conversation_status(status, duration: duration)
        update_message_status(status, duration: duration)
      end

      private

      def update_conversation_status(status, duration:)
        attrs = (@conversation.additional_attributes || {}).merge('call_status' => status)
        attrs['call_duration'] = duration if duration.present?
        @conversation.update!(additional_attributes: attrs)
      end

      def update_message_status(status, duration:)
        message = @conversation.messages.voice_calls.last
        return unless message

        data = (message.content_attributes['data'] || {}).merge('status' => status)
        data['duration'] = duration if duration.present?
        message.update!(content_attributes: message.content_attributes.merge('data' => data))
      end
    end
  end
end
