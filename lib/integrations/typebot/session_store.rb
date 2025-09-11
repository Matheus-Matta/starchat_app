# lib/integrations/typebot/session_store.rb
# frozen_string_literal: true
require 'json'

module Integrations
  module Typebot
    class SessionStore
      PREFIX = 'typebot:session:'

      def initialize(redis: nil)
        @use_alfred = defined?(::Redis::Alfred)
        @redis = redis || (!@use_alfred && defined?(::Redis) ? ::Redis.new(url: ENV['REDIS_URL']) : nil)
      end

      def get(conversation_id, hook_id)
        raw = read(key_for(conversation_id, hook_id))
        return nil if raw.blank?
        JSON.parse(raw)
        rescue JSON::ParserError
        nil
      end

      def set(conversation_id, hook_id, data, ttl_seconds)
        ttl = Integer(ttl_seconds || 0) rescue 0
        ttl = 86_400 if ttl <= 0  
        payload = data.is_a?(String) ? data : JSON.dump(data)
        write(key_for(conversation_id, hook_id), payload, ttl)
        data
      end

      def del(conversation_id, hook_id)
        delete(key_for(conversation_id, hook_id))
      end

      private

      def key_for(conversation_id, hook_id)
        "#{PREFIX}#{hook_id}:#{conversation_id}"
      end

      def read(key)
        @use_alfred ? ::Redis::Alfred.get(key) : @redis&.get(key)
      end

      def write(key, value, ttl)
        if @use_alfred
            ::Redis::Alfred.setex(key, value, ttl)   
        else
            @redis&.set(key, value, ex: ttl)
        end
      end

      def delete(key)
        @use_alfred ? ::Redis::Alfred.delete(key) : @redis&.del(key)
      end
    end
  end
end
