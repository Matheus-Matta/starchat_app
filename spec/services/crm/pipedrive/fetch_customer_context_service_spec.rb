require 'rails_helper'

RSpec.describe Crm::Pipedrive::FetchCustomerContextService do
  let(:account) { create(:account) }
  # Create contact with a Brazilian phone number including +55
  let(:contact) { create(:contact, account: account, phone_number: '+5521966621486', email: 'test@example.com') }
  let(:hook) { create(:integrations_hook, account: account, app_id: 'pipedrive', settings: { 'api_token' => 'test_token', 'base_url' => 'https://api.pipedrive.com' }) }
  
  subject { described_class.new(contact: contact) }

  before do
    # Mock the hook finding
    allow(account.hooks).to receive(:find_by).with(app_id: 'pipedrive').and_return(hook)
  end

  describe '#perform' do
    let(:client_double) { instance_double(PipedriveClient) }

    before do
      allow(PipedriveClient).to receive(:new).and_return(client_double)
      # Default empty responses for details to avoid nil errors in service execution
      allow(client_double).to receive(:person_details).and_return({ 'success' => true, 'data' => { 'name' => 'John Doe', 'id' => 123 } })
      allow(client_double).to receive(:deals).and_return({ 'data' => [] })
      allow(client_double).to receive(:activities).and_return({ 'data' => [] })
      allow(client_double).to receive(:leads).and_return({ 'data' => [] })
      allow(client_double).to receive(:notes).and_return({ 'data' => [] })
    end

    context 'when contact is found by exact match with full number (55)' do
      it 'matches and saves pipedrive_person_id' do
        # Expect search with full number 5521966621486
        allow(client_double).to receive(:search_person).with(term: '5521966621486', exact_match: true).and_return({
          'success' => true,
          'data' => {
            'items' => [
              { 'item' => { 'id' => 123, 'organization' => { 'id' => 1, 'name' => 'Org' } } }
            ]
          }
        })

        result = subject.perform

        expect(result[:pipedrive][:person]).to be_present
        expect(contact.reload.custom_attributes['pipedrive_person_id']).to eq(123)
      end
    end

    context 'when contact is NOT found by full number, but found without 55' do
      it 'tries searching without 55 prefix and matches' do
        # First call fails (full number)
        allow(client_double).to receive(:search_person).with(term: '5521966621486', exact_match: true).and_return({ 'success' => true, 'data' => { 'items' => [] } })
        
        # Second call succeeds (without 55) -> 21966621486
        allow(client_double).to receive(:search_person).with(term: '21966621486', exact_match: true).and_return({
          'success' => true,
          'data' => {
            'items' => [
              { 'item' => { 'id' => 456 } }
            ]
          }
        })

        result = subject.perform
        expect(result[:pipedrive][:person]).to be_present
        expect(contact.reload.custom_attributes['pipedrive_person_id']).to eq(456)
      end
    end

    context 'when contact is NOT found by any exact match, but found by fuzzy search' do
      it 'tries fuzzy search as last resort' do
         # Fail 1
         allow(client_double).to receive(:search_person).with(term: '5521966621486', exact_match: true).and_return({ 'success' => true, 'data' => { 'items' => [] } })
         # Fail 2
         allow(client_double).to receive(:search_person).with(term: '21966621486', exact_match: true).and_return({ 'success' => true, 'data' => { 'items' => [] } })
         
         # Success Fuzzy
         allow(client_double).to receive(:search_person).with(term: '21966621486', exact_match: false).and_return({
          'success' => true,
          'data' => {
            'items' => [
              { 'item' => { 'id' => 789 } }
            ]
          }
        })

        result = subject.perform
        expect(result[:pipedrive][:person]).to be_present
        expect(contact.reload.custom_attributes['pipedrive_person_id']).to eq(789)
      end
    end

    context 'when Pipedrive returns API error' do
      it 'handles error gracefully' do
        allow(client_double).to receive(:search_person).and_return(nil) # Simulating client returning nil on error

        result = subject.perform
        expect(result[:found]).to eq(false)
        expect(result[:error]).to include('Pipedrive API Error')
      end
    end
  end
end
