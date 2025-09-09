# frozen_string_literal: true

require 'uri'
require 'action_view'

module Integrations
  module Typebot
    class ProcessorService
      include ActionView::Helpers::SanitizeHelper

      def initialize(hook:, event:)
        @hook  = hook
        @event = event.deep_symbolize_keys
      end

      def perform
        return unless @event[:name].to_s == 'message_created'
        message = Message.find_by(id: @event.dig(:data, :message_id))
        return unless message&.incoming?
        return unless message.conversation.inbox_id == @hook.inbox_id

        settings  = (@hook.settings || {}).stringify_keys
        public_id = settings['public_id'] || extract_public_id(settings['share_url'])
        api_token = settings['api_token'].to_s
        ttl       = (settings['session_ttl_seconds'] || 86_400).to_i
        return if public_id.blank? || api_token.blank?

        client = Client.new(api_token: api_token)
        store  = SessionStore.new
        sess   = store.get(message.conversation_id)

        response =
          if sess.nil?
            client.start_chat(public_id: public_id, payload: start_payload(message))
          else
            client.continue_chat(session_id: sess['session_id'], payload: continue_payload(message))
          end

        if response['sessionId']
          store.set(message.conversation_id,
                    { 'session_id' => response['sessionId'], 'result_id' => response['resultId'] },
                    ttl)
        end

        publish_text_messages!(message.conversation, response)

        store.del(message.conversation_id) unless response['input'].present?
      rescue => e
        Rails.logger.error("[Typebot] Processor error: #{e.class} - #{e.message}")
      end

      private

      def extract_public_id(share_url)
        return nil if share_url.blank?
        URI.parse(share_url).path.split('/').last
      rescue
        nil
      end

      def sanitized_text(str)
        str.to_s.strip
      end

      def start_payload(message)
        {
          message: { type: 'text', text: sanitized_text(message.content) },
          isStreamEnabled: false,
          isOnlyRegistering: false,
          textBubbleContentFormat: 'richText',
          prefilledVariables: prefilled_from_contact(message.conversation&.contact)
        }
      end

      def continue_payload(message)
        {
          message: { type: 'text', text: sanitized_text(message.content) },
          textBubbleContentFormat: 'richText'
        }
      end

      def prefilled_from_contact(contact)
        return {} unless contact
        {
          'Name'  => contact.name,
          'Email' => contact.email,
          'Phone' => contact.phone_number
        }.compact
      end

      def publish_text_messages!(conversation, api_response)
        msgs = Array(api_response['messages'])
        return if msgs.empty?

        msgs.each do |m|
          next unless m['type'] == 'text'
          text = m.dig('content', 'richText') || m['message']
          next if text.blank?

          plain = strip_tags(text.to_s).squish
          next if plain.blank?

          conversation.messages.create!(
            message_type: :outgoing,
            content: plain,
            private: false
          )
        end
      end
    end
  end
end
