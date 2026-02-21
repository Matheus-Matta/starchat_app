# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Starchat::LogUserOfflineJob, type: :job do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:account_user) { account.account_users.find_by(user_id: user.id) }

  before { account_user.update_columns(availability: 0) } # 0 = online

  def presence_expired!
    allow(::OnlineStatusTracker).to receive(:get_presence).and_return(false)
  end

  def presence_active!
    allow(::OnlineStatusTracker).to receive(:get_presence).and_return(true)
  end

  # ---------------------------------------------------------------------------
  # Caso principal: cria audit log quando usuário ficou offline de verdade
  # ---------------------------------------------------------------------------
  describe '#perform' do
    context 'when user is online in DB and presence expired in Redis (truly offline)' do
      before { presence_expired! }

      it 'creates an availability_change audit log' do
        expect {
          described_class.perform_now(user.id, account.id, 'connection_lost')
        }.to change(Starchat::AuditLog, :count).by(1)
      end

      it 'records the correct availability_from, availability_to and reason' do
        described_class.perform_now(user.id, account.id, 'connection_lost')

        audit = Starchat::AuditLog.last
        expect(audit.action).to eq('availability_change')
        expect(audit.audited_changes['availability_from']).to eq('online')
        expect(audit.audited_changes['availability_to']).to eq('offline')
        expect(audit.audited_changes['reason']).to eq('connection_lost')
        expect(audit.audited_changes['triggered_by']).to eq('system')
      end

      it 'associates the log with the correct user and account' do
        described_class.perform_now(user.id, account.id, 'connection_lost')

        audit = Starchat::AuditLog.last
        expect(audit.auditable).to eq(user)
        expect(audit.associated).to eq(account)
      end

      it 'defaults reason to connection_lost when omitted' do
        described_class.perform_now(user.id, account.id)

        audit = Starchat::AuditLog.last
        expect(audit.audited_changes['reason']).to eq('connection_lost')
      end
    end

    # -------------------------------------------------------------------------
    # Usuário reconectou – presença ainda ativa no Redis
    # -------------------------------------------------------------------------
    context 'when user reconnected (presence still active in Redis)' do
      before { presence_active! }

      it 'does NOT create an audit log' do
        expect {
          described_class.perform_now(user.id, account.id, 'connection_lost')
        }.not_to change(Starchat::AuditLog, :count)
      end
    end

    # -------------------------------------------------------------------------
    # Usuário já está offline no DB (foi manualmente para offline antes de fechar)
    # O profiles_controller já registrou esse evento – não duplicar
    # -------------------------------------------------------------------------
    context 'when user is already offline in DB' do
      before do
        presence_expired!
        account_user.update_columns(availability: 1) # 1 = offline
      end

      it 'does NOT create a duplicate offline audit log' do
        expect {
          described_class.perform_now(user.id, account.id, 'connection_lost')
        }.not_to change(Starchat::AuditLog, :count)
      end
    end

    # -------------------------------------------------------------------------
    # Registros não encontrados
    # -------------------------------------------------------------------------
    context 'when user does not exist' do
      before { presence_expired! }

      it 'returns early without error' do
        expect {
          described_class.perform_now(0, account.id, 'connection_lost')
        }.not_to change(Starchat::AuditLog, :count)
      end
    end

    context 'when account does not exist' do
      before { presence_expired! }

      it 'returns early without error' do
        expect {
          described_class.perform_now(user.id, 0, 'connection_lost')
        }.not_to change(Starchat::AuditLog, :count)
      end
    end

    # -------------------------------------------------------------------------
    # Status busy também deve registrar offline ao desconectar
    # -------------------------------------------------------------------------
    context 'when user is busy (not offline) and presence expired' do
      before do
        presence_expired!
        account_user.update_columns(availability: 2) # 2 = busy
      end

      it 'creates an audit log with availability_from: busy' do
        expect {
          described_class.perform_now(user.id, account.id, 'connection_lost')
        }.to change(Starchat::AuditLog, :count).by(1)

        audit = Starchat::AuditLog.last
        expect(audit.audited_changes['availability_from']).to eq('busy')
        expect(audit.audited_changes['availability_to']).to eq('offline')
      end
    end
  end
end
