# starchat/app/jobs/starchat/log_user_offline_job.rb
# frozen_string_literal: true

# Job disparado quando um usuário desconecta do WebSocket (aba/navegador fechado).
# É agendado com delay equal a OnlineStatusTracker::PRESENCE_DURATION para que
# apenas registre no audit log se o usuário realmente ficou offline (não reconectou).
#
# Reason possíveis:
#   - connection_lost: WebSocket desconectado (aba fechada, navegador fechado, queda de rede)
#   - session_expired: Sessão expirada
class Starchat::LogUserOfflineJob < ApplicationJob
  queue_as :default

  def perform(user_id, account_id, reason = 'connection_lost')
    user = User.find_by(id: user_id)
    account = Account.find_by(id: account_id)
    return unless user && account

    # Se o usuário já reconectou (presença ativa no Redis), não registra
    return if ::OnlineStatusTracker.get_presence(account_id, 'User', user_id)

    account_user = account.account_users.find_by(user_id: user_id)
    return unless account_user

    previous_availability = account_user.availability.to_s

    # Se o usuário já está offline no DB, outro mecanismo (ex: mudança manual via
    # profiles#availability) já registrou o evento. Não duplicar.
    return if previous_availability == 'offline'

    Starchat::AuditLog.create(
      auditable: user,
      action: 'availability_change',
      user: user,
      associated: account,
      associated_type: 'Account',
      associated_id: account_id,
      remote_address: nil,
      audited_changes: {
        availability_from: previous_availability,
        availability_to: 'offline',
        reason: reason,
        triggered_by: 'system'
      }
    )

    Rails.logger.info(
      "[Starchat::LogUserOfflineJob] Logged offline for user=#{user_id} account=#{account_id} " \
      "reason=#{reason} prev=#{previous_availability}"
    )
  rescue StandardError => e
    Rails.logger.error("[Starchat::LogUserOfflineJob] #{e.class}: #{e.message}")
  end
end
