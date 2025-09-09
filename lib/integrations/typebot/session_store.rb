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

      def get(conversation_id)
        raw = read(key_for(conversation_id))
        raw.present? ? JSON.parse(raw) : nil
      rescue JSON::ParserError
        nil
      end

      def set(conversation_id, data, ttl_seconds)
        write(key_for(conversation_id), JSON.dump(data), ttl_seconds.to_i)
        data
      end

      def del(conversation_id)
        delete(key_for(conversation_id))
      end

      private

      def key_for(id) = "#{PREFIX}#{id}"

      def read(key)
        if @use_alfred
          ::Redis::Alfred.get(key)
        else
          @redis&.get(key)
        end
      end

      def write(key, value, ttl)
        if @use_alfred
          ::Redis::Alfred.setex(key, ttl, value)
        else
          @redis&.set(key, value, ex: ttl)
        end
      end

      def delete(key)
        if @use_alfred
          ::Redis::Alfred.delete(key)
        else
          @redis&.del(key)
        end
      end
    end
  end
end
