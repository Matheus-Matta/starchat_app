module Voice
  module Conference
    class Name
      def self.for(conversation)
        "voice-#{conversation.display_id}-#{SecureRandom.hex(4)}"
      end
    end
  end
end
