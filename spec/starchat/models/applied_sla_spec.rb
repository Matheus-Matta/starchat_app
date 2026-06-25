require 'rails_helper'

RSpec.describe AppliedSla, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:sla_policy) }
    it { is_expected.to belong_to(:account) }
    it { is_expected.to belong_to(:conversation) }
  end

  describe 'push_event_data' do
    it 'returns the correct hash' do
      applied_sla = create(:applied_sla)
      expect(applied_sla.push_event_data).to eq(
        {
          id: applied_sla.id,
          sla_id: applied_sla.sla_policy_id,
          sla_status: applied_sla.sla_status,
          created_at: applied_sla.created_at.to_i,
          updated_at: applied_sla.updated_at.to_i,
          sla_description: applied_sla.sla_policy.description,
          sla_name: applied_sla.sla_policy.name,
          sla_first_response_time_threshold: applied_sla.sla_policy.first_response_time_threshold,
          sla_next_response_time_threshold: applied_sla.sla_policy.next_response_time_threshold,
          sla_only_during_business_hours: applied_sla.sla_policy.only_during_business_hours,
          sla_resolution_time_threshold: applied_sla.sla_policy.resolution_time_threshold
        }
      )
    end
  end

  describe 'validates_factory' do
    it 'creates valid applied sla policy object' do
      applied_sla = create(:applied_sla)
      expect(applied_sla.sla_status).to eq 'active'
    end
  end

  describe '.filter_by_label_list' do
    let(:account) { create(:account) }
    let(:billing_conversation) { create(:conversation, account: account) }
    let(:urgent_conversation) { create(:conversation, account: account) }
    let(:other_conversation) { create(:conversation, account: account) }
    let!(:billing_sla) { create(:applied_sla, account: account, conversation: billing_conversation) }
    let!(:urgent_sla) { create(:applied_sla, account: account, conversation: urgent_conversation) }
    let!(:other_sla) { create(:applied_sla, account: account, conversation: other_conversation) }

    before do
      billing_conversation.label_list.add('billing')
      billing_conversation.save!
      urgent_conversation.label_list.add('urgent')
      urgent_conversation.save!
      other_conversation.label_list.add('spam')
      other_conversation.save!
    end

    it 'filters by a single label' do
      expect(AppliedSla.filter_by_label_list('billing')).to contain_exactly(billing_sla)
    end

    it 'filters by multiple labels combined with OR' do
      expect(AppliedSla.filter_by_label_list(%w[billing urgent])).to contain_exactly(billing_sla, urgent_sla)
    end

    it 'returns all records when blank' do
      expect(AppliedSla.filter_by_label_list(nil).to_a).to contain_exactly(billing_sla, urgent_sla, other_sla)
    end
  end
end
