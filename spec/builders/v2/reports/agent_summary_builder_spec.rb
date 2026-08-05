require 'rails_helper'

RSpec.describe V2::Reports::AgentSummaryBuilder do
  let(:account) { create(:account) }
  let(:user1) { create(:user, account: account, role: :agent) }
  let(:user2) { create(:user, account: account, role: :agent) }

  let(:params) do
    {
      business_hours: business_hours,
      since: 1.week.ago.beginning_of_day,
      until: Time.current.end_of_day
    }
  end
  let(:builder) { described_class.new(account: account, params: params) }

  describe '#build' do
    context 'when there is team data' do
      before do
        c1 = create(:conversation, account: account, assignee: user1, created_at: Time.current)
        c2 = create(:conversation, account: account, assignee: user2, created_at: Time.current)
        create(
          :reporting_event,
          account: account,
          conversation: c2,
          user: user2,
          name: 'conversation_resolved',
          value: 50,
          value_in_business_hours: 40,
          created_at: Time.current
        )
        create(
          :reporting_event,
          account: account,
          conversation: c1,
          user: user1,
          name: 'first_response',
          value: 20,
          value_in_business_hours: 10,
          created_at: Time.current
        )
        create(
          :reporting_event,
          account: account,
          conversation: c1,
          user: user1,
          name: 'reply_time',
          value: 30,
          value_in_business_hours: 15,
          created_at: Time.current
        )
        create(
          :reporting_event,
          account: account,
          conversation: c1,
          user: user1,
          name: 'reply_time',
          value: 40,
          value_in_business_hours: 25,
          created_at: Time.current
        )
      end

      context 'when business hours is disabled' do
        let(:business_hours) { false }

        it 'returns the correct team stats' do
          report = builder.build

          expect(report).to eq(
            [
              {
                id: user1.id,
                conversations_count: 1,
                resolved_conversations_count: 0,
                avg_resolution_time: nil,
                avg_first_response_time: 20.0,
                avg_reply_time: 35.0,
                no_first_reply_count: 1,
                waiting_count: 1,
                csat_score: nil,
                sla_hit_rate: nil
              },
              {
                id: user2.id,
                conversations_count: 1,
                resolved_conversations_count: 1,
                avg_resolution_time: 50.0,
                avg_first_response_time: nil,
                avg_reply_time: nil,
                no_first_reply_count: 1,
                waiting_count: 1,
                csat_score: nil,
                sla_hit_rate: nil
              }
            ]
          )
        end
      end

      context 'when business hours is enabled' do
        let(:business_hours) { true }

        it 'uses business hours values' do
          report = builder.build

          expect(report).to eq(
            [
              {
                id: user1.id,
                conversations_count: 1,
                resolved_conversations_count: 0,
                avg_resolution_time: nil,
                avg_first_response_time: 10.0,
                avg_reply_time: 20.0,
                no_first_reply_count: 1,
                waiting_count: 1,
                csat_score: nil,
                sla_hit_rate: nil
              },
              {
                id: user2.id,
                conversations_count: 1,
                resolved_conversations_count: 1,
                avg_resolution_time: 40.0,
                avg_first_response_time: nil,
                avg_reply_time: nil,
                no_first_reply_count: 1,
                waiting_count: 1,
                csat_score: nil,
                sla_hit_rate: nil
              }
            ]
          )
        end
      end
    end

    context 'when there is no team data' do
      let!(:new_user) { create(:user, account: account, role: :agent) }
      let(:business_hours) { false }

      it 'returns zero values' do
        report = builder.build

        expect(report).to include(
          {
            id: new_user.id,
            conversations_count: 0,
            resolved_conversations_count: 0,
            avg_resolution_time: nil,
            avg_first_response_time: nil,
            avg_reply_time: nil,
            no_first_reply_count: 0,
            waiting_count: 0,
            csat_score: nil,
            sla_hit_rate: nil
          }
        )
      end
    end

    context 'CSAT score and SLA hit rate' do
      let(:business_hours) { false }

      context 'when the agent has CSAT survey responses in the period' do
        let!(:conversation) { create(:conversation, account: account, assignee: user1, created_at: Time.current) }

        before do
          create(:csat_survey_response, account: account, conversation: conversation, assigned_agent: user1, rating: 5, created_at: Time.current)
          create(:csat_survey_response, account: account, conversation: conversation, assigned_agent: user1, rating: 4, created_at: Time.current)
          create(:csat_survey_response, account: account, conversation: conversation, assigned_agent: user1, rating: 2, created_at: Time.current)
          # outside the requested since/until range - must not affect the score
          create(:csat_survey_response, account: account, conversation: conversation, assigned_agent: user1, rating: 1, created_at: 2.years.ago)
        end

        it 'computes the percentage of positive (4-5 star) responses within the period' do
          report = builder.build
          user1_stats = report.find { |stats| stats[:id] == user1.id }

          expect(user1_stats[:csat_score]).to eq(66.67)
        end
      end

      context 'when the agent has no CSAT survey responses' do
        before { user1 }

        it 'returns nil instead of a misleading 0%' do
          report = builder.build
          user1_stats = report.find { |stats| stats[:id] == user1.id }

          expect(user1_stats[:csat_score]).to be_nil
        end
      end

      context 'when the agent has SLAs applied in the period' do
        let!(:conversation) { create(:conversation, account: account, assignee: user1, created_at: Time.current) }
        let!(:sla_policy) { create(:sla_policy, account: account) }

        before do
          create(:applied_sla, account: account, sla_policy: sla_policy, conversation: conversation, sla_status: :hit, created_at: Time.current)
          create(:applied_sla, account: account, sla_policy: sla_policy,
                                conversation: create(:conversation, account: account, assignee: user1, created_at: Time.current),
                                sla_status: :missed, created_at: Time.current)
          # outside the requested since/until range - must not affect the rate
          create(:applied_sla, account: account, sla_policy: sla_policy,
                                conversation: create(:conversation, account: account, assignee: user1, created_at: Time.current),
                                sla_status: :missed, created_at: 2.years.ago)
        end

        it 'computes the percentage of applied SLAs that were hit within the period' do
          report = builder.build
          user1_stats = report.find { |stats| stats[:id] == user1.id }

          expect(user1_stats[:sla_hit_rate]).to eq(50.0)
        end
      end

      context 'when the agent has no SLAs applied' do
        before { user1 }

        it 'returns nil instead of a misleading 100%' do
          report = builder.build
          user1_stats = report.find { |stats| stats[:id] == user1.id }

          expect(user1_stats[:sla_hit_rate]).to be_nil
        end
      end
    end

    # Regression check: waiting_count/no_first_reply_count must stay scoped to OPEN
    # conversations only. A resolved/pending/snoozed conversation can still have
    # waiting_since set (it's only cleared on resolution, and pending/snoozed never
    # clear it) and first_reply_created_at nil, so without the `.open` scope it would
    # incorrectly inflate these columns for conversations that are no longer active.
    context 'when conversations are not open' do
      let(:business_hours) { false }

      let!(:resolved_conversation) do
        create(:conversation, account: account, assignee: user1, status: :resolved, created_at: Time.current)
      end
      let!(:pending_conversation) do
        create(:conversation, account: account, assignee: user1, status: :pending, created_at: Time.current)
      end
      let!(:snoozed_conversation) do
        create(:conversation, account: account, assignee: user1, status: :snoozed, created_at: Time.current)
      end

      it 'excludes them from waiting_count and no_first_reply_count' do
        report = builder.build
        user1_stats = report.find { |stats| stats[:id] == user1.id }

        expect(user1_stats[:waiting_count]).to eq(0)
        expect(user1_stats[:no_first_reply_count]).to eq(0)
      end
    end

    # Regression check for the fix: waiting_count/no_first_reply_count used to be computed
    # as a live "right now" snapshot that ignored params[:since]/params[:until] entirely,
    # while every other metric in this same report row (conversations_count, avg_*_time,
    # resolved_conversations_count) was scoped to that range. On the Summary Reports UI,
    # which has a visible date-range picker, that meant a conversation created long before
    # the selected period still showed up under "Aguardando"/"Sem Resposta" even though
    # conversations_count correctly reported 0 for the same row - a visible divergence
    # between columns of the same table. Both fields must now respect the requested range.
    context 'when a conversation was created outside the requested since/until range' do
      let(:business_hours) { false }

      let!(:old_unanswered_conversation) do
        create(:conversation, account: account, assignee: user1, status: :open, created_at: 2.years.ago)
      end

      it 'excludes it from waiting_count/no_first_reply_count, consistently with conversations_count' do
        report = builder.build
        user1_stats = report.find { |stats| stats[:id] == user1.id }

        expect(user1_stats[:conversations_count]).to eq(0)
        expect(user1_stats[:waiting_count]).to eq(0)
        expect(user1_stats[:no_first_reply_count]).to eq(0)
      end
    end

    context 'when a conversation was created inside the requested since/until range' do
      let(:business_hours) { false }

      let!(:recent_unanswered_conversation) do
        create(:conversation, account: account, assignee: user1, status: :open, created_at: 2.days.ago)
      end

      it 'still counts it in waiting_count/no_first_reply_count' do
        report = builder.build
        user1_stats = report.find { |stats| stats[:id] == user1.id }

        expect(user1_stats[:conversations_count]).to eq(1)
        expect(user1_stats[:waiting_count]).to eq(1)
        expect(user1_stats[:no_first_reply_count]).to eq(1)
      end
    end
  end
end
