require 'rails_helper'

RSpec.describe Monitoring::OperationalSnapshotBuilder do
  describe '#build' do
    let(:account) { create(:account) }
    let(:online_agent) { create(:user, account: account, role: :agent) }
    let(:busy_agent) { create(:user, account: account, role: :agent) }
    let(:offline_agent) { create(:user, account: account, role: :agent) }

    let!(:account_user_online) { account.account_users.find_by(user: online_agent) }
    let!(:account_user_busy) { account.account_users.find_by(user: busy_agent) }
    let!(:account_user_offline) { account.account_users.find_by(user: offline_agent) }

    let!(:whatsapp_channel) { create(:channel_whatsapp, account: account, sync_templates: false, validate_provider_config: false) }
    let!(:inbox_online) { whatsapp_channel.inbox.tap { |inbox| inbox.update!(name: 'WhatsApp Comercial') } }

    let!(:email_channel) { create(:channel_email, account: account) }
    let!(:inbox_offline) { email_channel.inbox.tap { |inbox| inbox.update!(name: 'Email SAC') } }

    let!(:telegram_channel) { create(:channel_telegram, account: account) }
    let!(:inbox_neutral) { telegram_channel.inbox.tap { |inbox| inbox.update!(name: 'Telegram Alerts') } }

    let!(:evolution_channel) { create(:channel_evolution, account: account, state: :connected) }
    let!(:inbox_evolution) do
      evolution_channel.inbox.tap { |inbox| inbox.update!(name: 'Api teste') }
    end

    before do
      account_user_online.update!(availability: :online, active_at: 1.minute.ago)
      account_user_busy.update!(availability: :busy, active_at: 8.minutes.ago)
      account_user_offline.update!(availability: :offline, active_at: nil)

      create(:inbox_member, inbox: inbox_online, user: online_agent)
      create(:inbox_member, inbox: inbox_online, user: busy_agent)
      create(:inbox_member, inbox: inbox_offline, user: busy_agent)

      create(:conversation, account: account, inbox: inbox_online, assignee: online_agent,
                             status: :open, waiting_since: 3.minutes.ago, last_activity_at: 2.minutes.ago)
      create(:conversation, account: account, inbox: inbox_online, assignee: online_agent,
                             status: :open, last_activity_at: 1.minute.ago)
      create(:conversation, account: account, inbox: inbox_online, status: :open,
                             last_activity_at: 30.seconds.ago)

      create(:conversation, account: account, inbox: inbox_offline, assignee: busy_agent,
                             status: :open, last_activity_at: 8.minutes.ago)
      create(:conversation, account: account, inbox: inbox_offline, status: :open,
                             waiting_since: 15.minutes.ago, last_activity_at: 12.minutes.ago)

      email_channel.prompt_reauthorization!

      # inbox_offline intentionally has no recent activity and no members
      allow(OnlineStatusTracker).to receive(:get_available_user_ids).with(account.id)
                                                                    .and_return([online_agent.id.to_s])
    end

    around do |example|
      travel_to(Time.zone.parse('2026-03-18 10:35:00 UTC')) { example.run }
    end

    it 'returns aggregated snapshot with inbox and agent metrics' do
      snapshot = described_class.new(account: account,
                                     warning_threshold: 5.minutes,
                                     offline_threshold: 20.minutes).build

      expect(snapshot[:summary]).to include(
        total_inboxes: 4,
        online_inboxes: 3,
        warning_inboxes: 0,
        offline_inboxes: 1,
        total_agents: 3,
        agents_available: 1,
        agents_busy: 1,
        agents_offline: 1,
        total_active_conversations: 5
      )

      whatsapp_card = snapshot[:inboxes].find { |inbox| inbox[:id] == inbox_online.id }
      expect(whatsapp_card).to include(
        status: 'online',
        agents_count: 2,
        online_agents_count: 1,
        active_conversations_count: 3,
        waiting_conversations_count: 3,
        unassigned_conversations_count: 1
      )

      email_card = snapshot[:inboxes].find { |inbox| inbox[:id] == inbox_offline.id }
      expect(email_card[:status]).to eq('offline')

      telegram_card = snapshot[:inboxes].find { |inbox| inbox[:id] == inbox_neutral.id }
      expect(telegram_card[:status]).to eq('online')

      evolution_card = snapshot[:inboxes].find { |inbox| inbox[:id] == inbox_evolution.id }
      expect(evolution_card[:status]).to eq('online')

      agent_entry = snapshot[:agents].find { |agent| agent[:id] == online_agent.id }
      expect(agent_entry).to include(
        availability_status: 'online',
        active_conversations_count: 2,
        inboxes_count: 1
      )

      expect(snapshot[:agents].map { |agent| agent[:availability_status] }).to contain_exactly('online', 'busy', 'offline')
    end

    it 'marks reauthorizable channels as offline when reauthorization is required' do
      email_channel.prompt_reauthorization!

      snapshot = described_class.new(account: account,
                                     warning_threshold: 5.minutes,
                                     offline_threshold: 20.minutes).build

      email_card = snapshot[:inboxes].find { |inbox| inbox[:id] == inbox_offline.id }
      expect(email_card[:status]).to eq('offline')
    end

    # Regression check: "Aguardando" (waiting_count) and "Sem Resposta" (no_first_reply_count)
    # must stay scoped to OPEN conversations only, at both the per-inbox and per-agent level.
    # A resolved conversation can still carry waiting_since: non-nil / first_reply_created_at:
    # nil in the DB, so without the `.open` scope it would keep inflating these columns after
    # it's been closed.
    context 'when conversations are not open' do
      it 'excludes resolved/pending/snoozed conversations from waiting and no-first-reply counts' do
        create(:conversation, account: account, inbox: inbox_online, assignee: online_agent,
                               status: :resolved, waiting_since: 1.minute.ago, last_activity_at: 1.minute.ago)
        create(:conversation, account: account, inbox: inbox_online, assignee: online_agent,
                               status: :pending, waiting_since: 1.minute.ago, last_activity_at: 1.minute.ago)
        create(:conversation, account: account, inbox: inbox_online, assignee: online_agent,
                               status: :snoozed, last_activity_at: 1.minute.ago)

        snapshot = described_class.new(account: account,
                                       warning_threshold: 5.minutes,
                                       offline_threshold: 20.minutes).build

        whatsapp_card = snapshot[:inboxes].find { |inbox| inbox[:id] == inbox_online.id }
        expect(whatsapp_card[:waiting_conversations_count]).to eq(3)

        agent_entry = snapshot[:agents].find { |agent| agent[:id] == online_agent.id }
        expect(agent_entry[:waiting_count]).to eq(2)
        expect(agent_entry[:no_first_reply_count]).to eq(2)
      end
    end
  end
end
