require 'rails_helper'

RSpec.describe Sla::EvaluateAppliedSlaService do
  let!(:account) { create(:account) }
  let!(:inbox) { create(:inbox, account: account) }
  let!(:sla_policy) do
    create(:sla_policy,
           account: account,
           first_response_time_threshold: nil,
           next_response_time_threshold: nil,
           resolution_time_threshold: nil)
  end
  let!(:conversation) do
    create(:conversation, account: account, inbox: inbox, created_at: 6.hours.ago)
  end
  let!(:applied_sla) do
    create(:applied_sla, conversation: conversation, sla_policy: sla_policy, account: account)
  end

  describe '#perform - SLA misses' do
    context 'when first response SLA is missed' do
      before { applied_sla.sla_policy.update(first_response_time_threshold: 1.hour) }

      it 'updates the SLA status to missed and logs a warning' do
        allow(Rails.logger).to receive(:warn)
        described_class.new(applied_sla: applied_sla).perform
        expect(Rails.logger).to have_received(:warn).with("SLA frt missed for conversation #{conversation.id} in account " \
                                                          "#{applied_sla.account_id} for sla_policy #{sla_policy.id}")
        expect(applied_sla.reload.sla_status).to eq('active_with_misses')
      end

      it 'creates SlaEvent only for frt miss' do
        described_class.new(applied_sla: applied_sla).perform

        expect(SlaEvent.where(applied_sla: applied_sla, event_type: 'frt').count).to eq(1)
        expect(SlaEvent.where(applied_sla: applied_sla, event_type: 'nrt').count).to eq(0)
        expect(SlaEvent.where(applied_sla: applied_sla, event_type: 'rt').count).to eq(0)
      end
    end

    context 'when next response SLA is missed' do
      before do
        applied_sla.sla_policy.update(next_response_time_threshold: 1.hour)
        conversation.update(first_reply_created_at: 5.hours.ago, waiting_since: 5.hours.ago)
      end

      it 'updates the SLA status to missed and logs a warning' do
        allow(Rails.logger).to receive(:warn)
        described_class.new(applied_sla: applied_sla).perform
        expect(Rails.logger).to have_received(:warn).with("SLA nrt missed for conversation #{conversation.id} in account " \
                                                          "#{applied_sla.account_id} for sla_policy #{sla_policy.id}")
        expect(applied_sla.reload.sla_status).to eq('active_with_misses')
      end

      it 'creates SlaEvent only for nrt miss' do
        described_class.new(applied_sla: applied_sla).perform

        expect(SlaEvent.where(applied_sla: applied_sla, event_type: 'frt').count).to eq(0)
        expect(SlaEvent.where(applied_sla: applied_sla, event_type: 'nrt').count).to eq(1)
        expect(SlaEvent.where(applied_sla: applied_sla, event_type: 'rt').count).to eq(0)
      end
    end

    context 'when resolution time SLA is missed' do
      before { applied_sla.sla_policy.update(resolution_time_threshold: 1.hour) }

      it 'updates the SLA status to missed and logs a warning' do
        allow(Rails.logger).to receive(:warn)
        described_class.new(applied_sla: applied_sla).perform
        expect(Rails.logger).to have_received(:warn).with("SLA rt missed for conversation #{conversation.id} in account " \
                                                          "#{applied_sla.account_id} for sla_policy #{sla_policy.id}")
        expect(applied_sla.reload.sla_status).to eq('active_with_misses')
      end

      it 'creates SlaEvent only for rt miss' do
        described_class.new(applied_sla: applied_sla).perform

        expect(SlaEvent.where(applied_sla: applied_sla, event_type: 'frt').count).to eq(0)
        expect(SlaEvent.where(applied_sla: applied_sla, event_type: 'nrt').count).to eq(0)
        expect(SlaEvent.where(applied_sla: applied_sla, event_type: 'rt').count).to eq(1)
      end
    end

    context 'when resolved conversation with resolution time SLA is missed' do
      before do
        conversation.resolved!
        applied_sla.sla_policy.update(resolution_time_threshold: 1.hour)
      end

      it 'does not update the SLA status to missed' do
        described_class.new(applied_sla: applied_sla).perform
        expect(applied_sla.reload.sla_status).to eq('hit')
      end
    end

    context 'when multiple SLAs are missed' do
      before do
        applied_sla.sla_policy.update(first_response_time_threshold: 1.hour, next_response_time_threshold: 1.hour, resolution_time_threshold: 1.hour)
        conversation.update(first_reply_created_at: 5.hours.ago, waiting_since: 5.hours.ago)
      end

      it 'updates the SLA status to missed and logs multiple warnings' do
        allow(Rails.logger).to receive(:warn)
        described_class.new(applied_sla: applied_sla).perform
        expect(Rails.logger).to have_received(:warn).with("SLA rt missed for conversation #{conversation.id} in account " \
                                                          "#{applied_sla.account_id} for sla_policy #{sla_policy.id}").exactly(1).time
        expect(Rails.logger).to have_received(:warn).with("SLA nrt missed for conversation #{conversation.id} in account " \
                                                          "#{applied_sla.account_id} for sla_policy #{sla_policy.id}").exactly(1).time
        expect(applied_sla.reload.sla_status).to eq('active_with_misses')
      end
    end
  end

  describe '#perform - SLA hits' do
    context 'when first response SLA is hit' do
      before do
        applied_sla.sla_policy.update(first_response_time_threshold: 6.hours)
        conversation.update(first_reply_created_at: 30.minutes.ago)
      end

      it 'sla remains active until conversation is resolved' do
        described_class.new(applied_sla: applied_sla).perform
        expect(applied_sla.reload.sla_status).to eq('active')
      end

      it 'updates the SLA status to hit and logs an info when conversation is resolved' do
        conversation.resolved!
        allow(Rails.logger).to receive(:info)
        described_class.new(applied_sla: applied_sla).perform
        expect(Rails.logger).to have_received(:info).with("SLA hit for conversation #{conversation.id} in account " \
                                                          "#{applied_sla.account_id} for sla_policy #{sla_policy.id}")
        expect(applied_sla.reload.sla_status).to eq('hit')
        expect(SlaEvent.count).to eq(0)
      end
    end

    context 'when next response SLA is hit' do
      before do
        applied_sla.sla_policy.update(next_response_time_threshold: 6.hours)
        conversation.update(first_reply_created_at: 30.minutes.ago, waiting_since: nil)
      end

      it 'sla remains active until conversation is resolved' do
        described_class.new(applied_sla: applied_sla).perform
        expect(applied_sla.reload.sla_status).to eq('active')
      end

      it 'updates the SLA status to hit and logs an info when conversation is resolved' do
        conversation.resolved!
        allow(Rails.logger).to receive(:info)
        described_class.new(applied_sla: applied_sla).perform
        expect(Rails.logger).to have_received(:info).with("SLA hit for conversation #{conversation.id} in account " \
                                                          "#{applied_sla.account_id} for sla_policy #{sla_policy.id}")
        expect(applied_sla.reload.sla_status).to eq('hit')
        expect(SlaEvent.count).to eq(0)
      end
    end

    context 'when resolution time SLA is hit' do
      before do
        applied_sla.sla_policy.update(resolution_time_threshold: 8.hours)
        conversation.resolved!
      end

      it 'updates the SLA status to hit and logs an info' do
        allow(Rails.logger).to receive(:info)
        described_class.new(applied_sla: applied_sla).perform
        expect(Rails.logger).to have_received(:info).with("SLA hit for conversation #{conversation.id} in account " \
                                                          "#{applied_sla.account_id} for sla_policy #{sla_policy.id}")
        expect(applied_sla.reload.sla_status).to eq('hit')
        expect(SlaEvent.count).to eq(0)
      end
    end
  end
end
