require 'rails_helper'

RSpec.describe Conversations::ReopenSnoozedConversationsJob do
  let!(:snoozed_till_5_minutes_ago) { create(:conversation, status: :snoozed, snoozed_until: 5.minutes.ago) }
  let!(:snoozed_till_tomorrow) { create(:conversation, status: :snoozed, snoozed_until: 1.day.from_now) }
  let!(:snoozed_indefinitely) { create(:conversation, status: :snoozed) }

  it 'enqueues the job' do
    expect { described_class.perform_later }.to have_enqueued_job(described_class)
      .on_queue('low')
  end

  context 'when called' do
    it 'reopens snoozed conversations whose snooze until has passed' do
      described_class.perform_now

      expect(snoozed_till_5_minutes_ago.reload.status).to eq 'open'
      expect(snoozed_till_tomorrow.reload.status).to eq 'snoozed'
      expect(snoozed_indefinitely.reload.status).to eq 'snoozed'
    end

    it 'resets last_activity_at on reopen so auto-resolution does not immediately close it' do
      snoozed_till_5_minutes_ago.update_column(:last_activity_at, 2.days.ago)

      freeze_time do
        described_class.perform_now
        expect(snoozed_till_5_minutes_ago.reload.last_activity_at).to be_within(1.second).of(Time.current)
      end
    end

    it 'does not touch last_activity_at for conversations still snoozed' do
      snoozed_till_tomorrow.update_column(:last_activity_at, 2.days.ago)

      described_class.perform_now

      expect(snoozed_till_tomorrow.reload.last_activity_at).to be_within(1.second).of(2.days.ago)
    end
  end

  # Regression: a conversation snoozed to the next day was reopening and being
  # auto-resolved within the same scheduler cycle because last_activity_at was stale.
  context 'when auto-resolution runs in the same cycle after reopen' do
    let(:account) { create(:account) }
    let!(:snoozed_conversation) do
      create(:conversation, account: account, status: :snoozed,
                            snoozed_until: 5.minutes.ago, last_activity_at: 2.days.ago)
    end

    before do
      account.update(auto_resolve_after: 1440) # 1 day in minutes
    end

    it 'does not immediately auto-resolve the reopened conversation' do
      described_class.perform_now
      Conversations::ResolutionJob.perform_now(account: account)

      expect(snoozed_conversation.reload.status).to eq('open')
    end
  end
end
