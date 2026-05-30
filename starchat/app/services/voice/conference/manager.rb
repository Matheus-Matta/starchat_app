module Voice
  module Conference
    class Manager
      def initialize(conversation:, event:, call_sid:, participant_label:)
        @conversation = conversation
        @event = event
        @call_sid = call_sid
        @participant_label = participant_label
      end

      def process
        # Process Twilio conference status events (start, join, leave, end)
      end
    end
  end
end
