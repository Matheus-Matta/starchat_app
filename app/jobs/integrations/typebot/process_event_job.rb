module Integrations
  module Typebot
    class ProcessEventJob < ApplicationJob
      queue_as :integrations

      def perform(hook_id, event_hash)
        hook = ::Integrations::Hook.find_by(id: hook_id, app_id: 'typebot')
        return unless hook

        ::Integrations::Typebot::ProcessorService
          .new(hook: hook, event: event_hash)
          .perform
      end
    end
  end
end