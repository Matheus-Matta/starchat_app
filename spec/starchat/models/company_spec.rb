require 'rails_helper'

RSpec.describe Company, type: :model do
  context 'with validations' do
    it { is_expected.to validate_presence_of(:account_id) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(100) }
    it { is_expected.to validate_length_of(:description).is_at_most(1000) }

    describe 'domain validation' do
      it { is_expected.to allow_value('example.com').for(:domain) }
      it { is_expected.to allow_value('sub.example.com').for(:domain) }
      it { is_expected.to allow_value('').for(:domain) }
      it { is_expected.to allow_value(nil).for(:domain) }
      it { is_expected.not_to allow_value('invalid-domain').for(:domain) }
      it { is_expected.not_to allow_value('.example.com').for(:domain) }
      it { is_expected.not_to allow_value('domain with spaces.com').for(:domain) }
    end

    describe 'domain uniqueness' do
      let(:account) { create(:account) }

      it 'prevents duplicate domains within same account' do
        create(:company, domain: 'dup.com', account: account)
        duplicate = build(:company, domain: 'dup.com', account: account)
        expect(duplicate).not_to be_valid
      end

      it 'allows same domain in different accounts' do
        other = create(:account)
        create(:company, domain: 'shared.com', account: other)
        company = build(:company, domain: 'shared.com', account: account)
        expect(company).to be_valid
      end

      it 'allows multiple companies with nil domain in same account' do
        create(:company, domain: nil, account: account)
        second = build(:company, domain: nil, account: account)
        expect(second).to be_valid
      end
    end
  end

  context 'with associations' do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to have_many(:contacts).dependent(:nullify) }
  end

  describe 'jsonb defaults' do
    it 'initializes additional_attributes as empty hash' do
      company = create(:company)
      expect(company.additional_attributes).to eq({})
    end

    it 'initializes custom_attributes as empty hash' do
      company = create(:company)
      expect(company.custom_attributes).to eq({})
    end
  end

  describe 'scopes' do
    let(:account) { create(:account) }
    let!(:company_b) { create(:company, name: 'B Company', account: account) }
    let!(:company_a) { create(:company, name: 'A Company', account: account) }
    let!(:company_c) { create(:company, name: 'C Company', account: account) }

    describe '.ordered_by_name' do
      it 'orders companies by name alphabetically' do
        companies = described_class.where(account: account).ordered_by_name
        expect(companies.map(&:name)).to eq([company_a.name, company_b.name, company_c.name])
      end
    end

    describe '.search_by_name_or_domain' do
      before do
        create(:company, name: 'Acme Corp', domain: 'acme.com', account: account)
        create(:company, name: 'Tech Hub', domain: 'techhub.io', account: account)
      end

      it 'matches by name (case insensitive)' do
        results = described_class.where(account: account).search_by_name_or_domain('acme')
        expect(results.map(&:name)).to include('Acme Corp')
      end

      it 'matches by domain' do
        results = described_class.where(account: account).search_by_name_or_domain('techhub.io')
        expect(results.map(&:name)).to include('Tech Hub')
      end

      it 'returns empty when nothing matches' do
        results = described_class.where(account: account).search_by_name_or_domain('zzznomatch')
        expect(results).to be_empty
      end
    end
  end

  describe '#record_activity_at!' do
    it 'updates last_activity_at when the new time is more recent' do
      company = create(:company, last_activity_at: 10.minutes.ago)
      new_activity = Time.zone.now
      company.record_activity_at!(new_activity)
      expect(company.reload.last_activity_at).to be_within(1.second).of(new_activity)
    end

    it 'does not move company activity backwards' do
      company = create(:company, last_activity_at: Time.zone.now)
      original_activity_at = company.last_activity_at

      company.record_activity_at!(1.hour.ago)

      expect(company.reload.last_activity_at).to be_within(1.second).of(original_activity_at)
    end

    it 'ignores updates within the rollup interval' do
      company = create(:company, last_activity_at: 1.minute.ago)
      original = company.last_activity_at

      company.record_activity_at!(30.seconds.ago)

      expect(company.reload.last_activity_at).to be_within(1.second).of(original)
    end
  end
end
