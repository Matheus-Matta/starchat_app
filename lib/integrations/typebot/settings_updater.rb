# lib/integrations/typebot/settings_updater.rb
module Integrations
  module Typebot
    class SettingsUpdater
      class UpdateError < StandardError; end

      def initialize(hook:, share_url: nil, api_token: nil, session_ttl_seconds: nil)
        @hook = hook
        @share_url = share_url
        @api_token = api_token
        @ttl = session_ttl_seconds
      end

      def perform
        raise UpdateError, 'Hook não encontrado' unless @hook
        s = (@hook.settings || {}).dup

        s['share_url'] = @share_url if @share_url.present?
        s['api_token'] = @api_token if @api_token.present?
        s['session_ttl_seconds'] = @ttl.to_i if @ttl.present?

        @hook.update!(settings: s)
        @hook
      rescue ActiveRecord::RecordInvalid => e
        raise UpdateError, e.record.errors.full_messages.join(', ')
      end
    end
  end
end
