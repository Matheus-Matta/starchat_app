module Integrations
    module Typebot
        class HookBuilder
            class BuildError < StandardError; end

            def initialize(account:, inbox_id:, share_url:, api_token:, session_ttl_seconds: nil)
                @account = account
                @inbox_id = inbox_id
                @share_url = share_url
                @public_id = URI.parse(share_url).path.split('/').last rescue nil
                @api_token = api_token
                @ttl = (session_ttl_seconds.presence || 86_400).to_i
                puts "[HookBuilder] Initialized with inbox_id=#{@inbox_id}, share_url=#{@share_url}, ttl=#{@ttl}"
            end

            def perform
                puts "[HookBuilder] Performing hook creation"
                raise BuildError, 'Inbox inválido' unless Inbox.exists?(@inbox_id)
                raise BuildError, 'Share URL inválida' if @share_url.blank?
                raise BuildError, 'API token ausente' if @api_token.blank?

                settings = {
                    'public_id' => @public_id,
                    'api_token' => @api_token,
                    'session_ttl_seconds' => @ttl
                }
                puts "[HookBuilder] Settings: #{settings.inspect}"

                Integrations::Hook.create!(
                    account: @account,
                    app_id: 'typebot',
                    hook_type: :inbox,
                    inbox_id: @inbox_id,
                    status: :enabled,
                    settings: settings
                ).tap do |hook|
                    puts "[HookBuilder] Hook created with id=#{hook.id}"
                end
            rescue ActiveRecord::RecordInvalid => e
                puts "[HookBuilder] Error: #{e.record.errors.full_messages.join(', ')}"
                raise BuildError, e.record.errors.full_messages.join(', ')
            end
        end
    end
end
