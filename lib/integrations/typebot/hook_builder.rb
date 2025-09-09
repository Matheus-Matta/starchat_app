module Integrations
  module Typebot
    class HookBuilder
      class BuildError < StandardError; end

      def initialize(account:, inbox_id:, share_url:, api_token:, session_ttl_seconds: nil)
        @account = account
        @inbox_id = inbox_id
        @share_url = share_url
        @api_token = api_token
        @ttl = (session_ttl_seconds.presence || 86_400).to_i
      end

      def perform
        raise BuildError, 'Inbox inválido' unless Inbox.exists?(@inbox_id)
        raise BuildError, 'Share URL inválida' if @share_url.blank?
        raise BuildError, 'API token ausente' if @api_token.blank?

        settings = {
          'share_url' => @share_url,
          'api_token' => @api_token,
          'session_ttl_seconds' => @ttl
        }

        Integrations::Hook.create!(
          account: @account,
          app_id: 'typebot',
          hook_type: :inbox,
          inbox_id: @inbox_id,
          status: :enabled,
          settings: settings
        )
      rescue ActiveRecord::RecordInvalid => e
        raise BuildError, e.record.errors.full_messages.join(', ')
      end
    end
  end
end
