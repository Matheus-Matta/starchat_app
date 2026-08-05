require 'rails_helper'

RSpec.describe V2::Reports::AgentConversationDetailBuilder do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:other_agent) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account) }

  let(:params) do
    {
      since: Time.utc(2026, 6, 1).beginning_of_day.to_i.to_s,
      until: Time.utc(2026, 6, 30).end_of_day.to_i.to_s,
      business_hours: false
    }
  end
  let(:builder) { described_class.new(account: account, agent: agent, params: params) }

  around { |example| travel_to(Time.utc(2026, 6, 30, 12, 0)) { example.run } }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('FRONTEND_URL', nil).and_return('https://app.example.com')
  end

  describe '#build' do
    context 'with a conversation that has messages and reporting events' do
      let!(:conversation) do
        create(:conversation, account: account, inbox: inbox, assignee: agent, created_at: Time.utc(2026, 6, 10))
      end

      before do
        create(:message, account: account, conversation: conversation, message_type: :incoming)
        create(:message, account: account, conversation: conversation, message_type: :incoming)
        create(:message, account: account, conversation: conversation, message_type: :outgoing)

        create(:reporting_event, account: account, conversation: conversation, name: 'first_response', value: 60, value_in_business_hours: 30)
        create(:reporting_event, account: account, conversation: conversation, name: 'reply_time', value: 20, value_in_business_hours: 10)
        create(:reporting_event, account: account, conversation: conversation, name: 'reply_time', value: 40, value_in_business_hours: 30)
        create(:reporting_event, account: account, conversation: conversation, name: 'conversation_resolved', value: 100, value_in_business_hours: 50)
      end

      it 'returns one row per conversation with per-conversation metrics and an absolute conversation link' do
        result = builder.build

        expect(result[:rows].size).to eq(1)
        row = result[:rows].first

        expect(row).to include(
          display_id: conversation.display_id,
          contact_name: conversation.contact.name,
          status: 'open',
          incoming_messages_count: 2,
          outgoing_messages_count: 1,
          first_response_time: 60.0,
          reply_time: 30.0,
          resolution_time: 100.0
        )
        expect(row[:conversation_url]).to eq(
          "https://app.example.com/app/accounts/#{account.id}/conversations/#{conversation.display_id}"
        )
      end

      it 'uses business-hours values when business_hours is enabled' do
        result = described_class.new(account: account, agent: agent, params: params.merge(business_hours: true)).build
        row = result[:rows].first

        expect(row[:first_response_time]).to eq(30.0)
        expect(row[:reply_time]).to eq(20.0)
        expect(row[:resolution_time]).to eq(50.0)
      end

      it 'aggregates totals across all rows: sums for message counts, averages for times' do
        result = builder.build

        expect(result[:totals]).to eq(
          conversations_count: 1,
          incoming_messages_count: 2,
          outgoing_messages_count: 1,
          avg_first_response_time: 60.0,
          avg_reply_time: 30.0,
          avg_resolution_time: 100.0
        )
      end
    end

    context 'with a conversation that has no reporting events yet' do
      let!(:conversation) do
        create(:conversation, account: account, inbox: inbox, assignee: agent, created_at: Time.utc(2026, 6, 10))
      end

      it 'returns nil (not zero) for the missing time metrics' do
        row = builder.build[:rows].first

        expect(row[:first_response_time]).to be_nil
        expect(row[:reply_time]).to be_nil
        expect(row[:resolution_time]).to be_nil
      end
    end

    context 'when there are no conversations for the agent' do
      it 'returns empty rows and nil averages instead of dividing by zero' do
        result = builder.build

        expect(result[:rows]).to eq([])
        expect(result[:totals]).to eq(
          conversations_count: 0,
          incoming_messages_count: 0,
          outgoing_messages_count: 0,
          avg_first_response_time: nil,
          avg_reply_time: nil,
          avg_resolution_time: nil
        )
      end
    end

    context 'scoping' do
      let!(:other_agent_conversation) do
        create(:conversation, account: account, inbox: inbox, assignee: other_agent, created_at: Time.utc(2026, 6, 10))
      end
      let!(:out_of_range_conversation) do
        create(:conversation, account: account, inbox: inbox, assignee: agent, created_at: Time.utc(2025, 1, 1))
      end

      it 'only includes conversations assigned to the given agent, created within the requested range' do
        expect(builder.build[:rows]).to eq([])
      end
    end
  end
end
