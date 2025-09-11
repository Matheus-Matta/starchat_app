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
                puts "[SettingsUpdater] Iniciando atualização de settings para hook: #{@hook&.id}"
                raise UpdateError, 'Hook não encontrado' unless @hook
                s = (@hook.settings || {}).dup

                if @share_url.present?
                    puts "[SettingsUpdater] Atualizando share_url: #{@share_url}"
                    s['share_url'] = @share_url
                end

                if @api_token.present?
                    puts "[SettingsUpdater] Atualizando api_token: #{@api_token}"
                    s['api_token'] = @api_token
                end

                if @ttl.present?
                    puts "[SettingsUpdater] Atualizando session_ttl_seconds: #{@ttl.to_i}"
                    s['session_ttl_seconds'] = @ttl.to_i
                end

                puts "[SettingsUpdater] Salvando settings: #{s.inspect}"
                @hook.update!(settings: s)
                puts "[SettingsUpdater] Atualização concluída para hook: #{@hook.id}"
                @hook
            rescue ActiveRecord::RecordInvalid => e
                puts "[SettingsUpdater] Erro ao atualizar: #{e.record.errors.full_messages.join(', ')}"
                raise UpdateError, e.record.errors.full_messages.join(', ')
            end
        end
    end
end
