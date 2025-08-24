require 'rails_helper'

RSpec.describe Sla::EvaluateAppliedSlaService do
  let!(:organization) { create(:organization) }
  let!(:agent) { create(:agent, organization: organization) }

  let!(:sla_policy) do
    create(:sla_policy,
           organization: organization,
           first_response_time_threshold: nil,
           next_response_time_threshold: nil,
           resolution_time_threshold: nil)
  end
  let!(:ticket) do
    create(:ticket,
           created_at: 6.hours.ago, assignee: agent,
           organization: sla_policy.organization,
           sla_policy: sla_policy)
  end
  let!(:applied_sla) { ticket.applied_sla }

  describe '#perform - SLA misses' do
    context 'when first response SLA is missed' do
      before { applied_sla.sla_policy.update(first_response_time_threshold: 1.hour) }

      it 'updates the SLA status to missed and logs a warning' do
        allow(Rails.logger).to receive(:warn)
        described_class.new(applied_sla: applied_sla).perform
        expect(Rails.logger).to have_received(:warn).with("SLA frt missed for ticket #{ticket.id} in organization " \
                                                          "#{applied_sla.organization_id} for sla_policy #{sla_policy.id}")
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
        ticket.update(first_reply_created_at: 5.hours.ago, waiting_since: 5.hours.ago)
      end

      it 'updates the SLA status to missed and logs a warning' do
        allow(Rails.logger).to receive(:warn)
        described_class.new(applied_sla: applied_sla).perform
        expect(Rails.logger).to have_received(:warn).with("SLA nrt missed for ticket #{ticket.id} in organization " \
                                                          "#{applied_sla.organization_id} for sla_policy #{sla_policy.id}")
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
        expect(Rails.logger).to have_received(:warn).with("SLA rt missed for ticket #{ticket.id} in organization " \
                                                          "#{applied_sla.organization_id} for sla_policy #{sla_policy.id}")

        expect(applied_sla.reload.sla_status).to eq('active_with_misses')
      end

      it 'creates SlaEvent only for rt miss' do
        described_class.new(applied_sla: applied_sla).perform

        expect(SlaEvent.where(applied_sla: applied_sla, event_type: 'frt').count).to eq(0)
        expect(SlaEvent.where(applied_sla: applied_sla, event_type: 'nrt').count).to eq(0)
        expect(SlaEvent.where(applied_sla: applied_sla, event_type: 'rt').count).to eq(1)
      end
    end

    context 'when resolved ticket with resolution time SLA is missed' do
      before do
        ticket.resolved!
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
        ticket.update(first_reply_created_at: 5.hours.ago, waiting_since: 5.hours.ago)
      end

      it 'updates the SLA status to missed and logs multiple warnings' do
        allow(Rails.logger).to receive(:warn)
        described_class.new(applied_sla: applied_sla).perform
        expect(Rails.logger).to have_received(:warn).with("SLA rt missed for ticket #{ticket.id} in organization " \
                                                          "#{applied_sla.organization_id} for sla_policy #{sla_policy.id}").exactly(1).time
        expect(Rails.logger).to have_received(:warn).with("SLA nrt missed for ticket #{ticket.id} in organization " \
                                                          "#{applied_sla.organization_id} for sla_policy #{sla_policy.id}").exactly(1).time
        expect(applied_sla.reload.sla_status).to eq('active_with_misses')
      end
    end
  end

  describe '#perform - SLA hits' do
    context 'when first response SLA is hit' do
      before do
        applied_sla.sla_policy.update(first_response_time_threshold: 6.hours)
        ticket.update(first_reply_created_at: 30.minutes.ago)
      end

      it 'sla remains active until ticket is resolved' do
        described_class.new(applied_sla: applied_sla).perform
        expect(applied_sla.reload.sla_status).to eq('active')
      end

      it 'updates the SLA status to hit and logs an info when ticket is resolved' do
        ticket.resolved!
        allow(Rails.logger).to receive(:info)
        described_class.new(applied_sla: applied_sla).perform
        expect(Rails.logger).to have_received(:info).with("SLA hit for ticket #{ticket.id} in organization " \
                                                          "#{applied_sla.organization_id} for sla_policy #{sla_policy.id}")
        expect(applied_sla.reload.sla_status).to eq('hit')
        expect(SlaEvent.count).to eq(0)
        expect(Notification.count).to eq(0)
      end
    end

    context 'when next response SLA is hit' do
      before do
        applied_sla.sla_policy.update(next_response_time_threshold: 6.hours)
        ticket.update(first_reply_created_at: 30.minutes.ago, waiting_since: nil)
      end

      it 'sla remains active until ticket is resolved' do
        described_class.new(applied_sla: applied_sla).perform
        expect(applied_sla.reload.sla_status).to eq('active')
      end

      it 'updates the SLA status to hit and logs an info when ticket is resolved' do
        ticket.resolved!
        allow(Rails.logger).to receive(:info)
        described_class.new(applied_sla: applied_sla).perform
        expect(Rails.logger).to have_received(:info).with("SLA hit for ticket #{ticket.id} in organization " \
                                                          "#{applied_sla.organization_id} for sla_policy #{sla_policy.id}")
        expect(applied_sla.reload.sla_status).to eq('hit')
        expect(SlaEvent.count).to eq(0)
      end
    end

    context 'when resolution time SLA is hit' do
      before do
        applied_sla.sla_policy.update(resolution_time_threshold: 8.hours)
        ticket.resolved!
      end

      it 'updates the SLA status to hit and logs an info' do
        allow(Rails.logger).to receive(:info)
        described_class.new(applied_sla: applied_sla).perform
        expect(Rails.logger).to have_received(:info).with("SLA hit for ticket #{ticket.id} in organization " \
                                                          "#{applied_sla.organization_id} for sla_policy #{sla_policy.id}")
        expect(applied_sla.reload.sla_status).to eq('hit')
        expect(SlaEvent.count).to eq(0)
      end
    end
  end

  describe 'SLA evaluation with frt hit, multiple nrt misses and rt miss' do
    before do
      applied_sla.sla_policy.update(
        first_response_time_threshold: 2.hours,
        next_response_time_threshold: 1.hour,
        resolution_time_threshold: 4.hours
      )

      create(:message, ticket: ticket, created_at: 6.hours.ago, message_type: :incoming)
      create(:message, ticket: ticket, created_at: 5.hours.ago, message_type: :outgoing)

      create(:message, ticket: ticket, created_at: 4.hours.ago, message_type: :incoming)
      described_class.new(applied_sla: applied_sla).perform

      create(:message, ticket: ticket, created_at: 3.hours.ago, message_type: :incoming)
      described_class.new(applied_sla: applied_sla).perform

      ticket.update(status: 'resolved')
      described_class.new(applied_sla: applied_sla).perform
    end

    it 'updates the SLA status to missed' do
      expect(applied_sla.reload.sla_status).to eq('missed')
    end

    it 'creates necessary sla events' do
      expect(SlaEvent.where(applied_sla: applied_sla, event_type: 'frt').count).to eq(0)
      expect(SlaEvent.where(applied_sla: applied_sla, event_type: 'nrt').count).to eq(2)
      expect(SlaEvent.where(applied_sla: applied_sla, event_type: 'rt').count).to eq(1)
    end
  end
end
