require 'rails_helper'

RSpec.describe Crm::Pipedrive::IncomingContactService do
  let(:account) { create(:account, locale: 'pt_BR') }
  let!(:hook) { create(:integrations_hook, account: account, app_id: 'pipedrive', settings: settings) }
  # Default settings: All Sync ON
  # Default settings: All Sync ON
  let(:settings) { 
    { 
      'api_token' => 'test_token', 
      'company_domain' => 'test',
      'pipedrive_url' => 'https://test.pipedrive.com',
      'sync_contacts' => true,
      'import_contacts' => true, # New Setting
      'sync_name' => true,
      'sync_email' => true,
      'sync_phone' => true,
      'sync_organization' => true
    } 
  }
  let(:service) { described_class.new(account: account) }
  let(:pipedrive_client_mock) { double }

  before do
    allow(PipedriveClient).to receive(:new).and_return(pipedrive_client_mock)
    allow(pipedrive_client_mock).to receive(:person_fields).and_return({'success' => true, 'data' => []})
  end

  describe '#create_or_update' do
    let(:payload) {
      {
        'id' => 123,
        'name' => 'Pipedrive User',
        'email' => [{'value' => 'user@pipedrive.com', 'primary' => true}],
        'phone' => [{'value' => '+5511999999999', 'primary' => true}],
        'org_id' => {'name' => 'Pipedrive Inc'}
      }
    }

    context 'Global Permissions' do
      context 'when sync_contacts is disabled' do
        before do
          hook.settings['sync_contacts'] = false
          hook.save!
        end
        it 'does not process the contact' do
          expect { service.create_or_update(payload) }.not_to change(Contact, :count)
        end
      end

      context 'when sync_contacts is disabled' do
        before do
          hook.settings['sync_contacts'] = false
          hook.save!
        end
        it 'does not process the contact' do
          expect { service.create_or_update(payload) }.not_to change(Contact, :count)
        end
      end
    end
    end

    context 'when contact does not exist (New)' do
      it 'creates a new contact with all fields populated' do
        expect {
          service.create_or_update(payload)
        }.to change(Contact, :count).by(1)

        contact = Contact.last
        expect(contact.name).to eq('Pipedrive User')
        expect(contact.email).to eq('user@pipedrive.com')
        expect(contact.phone_number).to eq('+5511999999999')
        expect(contact.additional_attributes['company_name']).to eq('Pipedrive Inc')
        expect(contact.additional_attributes['pipedrive_id']).to eq(123)
      end

      it 'populates attributes even if sync flag is false (because it is new record)' do
        hook.settings['sync_name'] = false
        hook.settings['sync_email'] = false
        hook.settings['sync_phone'] = false
        hook.save!

        expect {
          service.create_or_update(payload)
        }.to change(Contact, :count).by(1)

        contact = Contact.last
        # Requirements imply creation should populates available data
        expect(contact.name).to eq('Pipedrive User')
        expect(contact.email).to eq('user@pipedrive.com')
        expect(contact.phone_number).to eq('+5511999999999')
      end
    end

    context 'when contact already exists (Update)' do
      let!(:contact) { create(:contact, account: account, name: 'Chatwoot User', email: 'user@chatwoot.com', phone_number: '+5511888888888') }
      
      before do
        contact.additional_attributes ||= {}
        contact.additional_attributes['pipedrive_id'] = 123.to_s # String vs Int might matter, service handles logic
        contact.save!
      end

      context 'with Sync Enabled' do
        it 'updates all fields' do
          service.create_or_update(payload)
          contact.reload
          
          expect(contact.name).to eq('Pipedrive User')
          expect(contact.email).to eq('user@pipedrive.com')
          expect(contact.phone_number).to eq('+5511999999999')
          expect(contact.additional_attributes['company_name']).to eq('Pipedrive Inc')
        end
      end

      context 'with Sync Name Disabled' do
        before do
          hook.settings['sync_name'] = false
          hook.save!
        end

        it 'does NOT update the name' do
          service.create_or_update(payload)
          contact.reload
          expect(contact.name).to eq('Chatwoot User') # Original Name
          expect(contact.email).to eq('user@pipedrive.com') # Other field updated
        end
      end

      context 'with Sync Email Disabled' do
        before do
          hook.settings['sync_email'] = false
          hook.save!
        end

        it 'does NOT update the email' do
          service.create_or_update(payload)
          contact.reload
          expect(contact.email).to eq('user@chatwoot.com') # Original Email
          expect(contact.name).to eq('Pipedrive User') # Other field updated
        end
      end

      context 'with Sync Phone Disabled' do
        before do
          hook.settings['sync_phone'] = false
          hook.save!
        end

        it 'does NOT update the phone' do
          service.create_or_update(payload)
          contact.reload
          expect(contact.phone_number).to eq('+5511888888888') # Original Phone
          expect(contact.name).to eq('Pipedrive User')
        end
      end

      context 'with Sync Org Disabled' do
        before do
          hook.settings['sync_organization'] = false
          hook.save!
        end

        it 'does NOT update the organization' do
          service.create_or_update(payload)
          contact.reload
          expect(contact.additional_attributes['company_name']).to be_nil
        end
      end
    end

    context 'Organization lookup logic' do
      # When org_id is numeric, it tries to fetch from API
      let(:payload_numeric_org) {
        payload.merge('org_id' => 999)
      }

      it 'fetches organization name from API' do
        allow(pipedrive_client_mock).to receive(:organization_details).with(id: 999).and_return({
          'success' => true,
          'data' => { 'name' => 'API Fetched Corp' }
        })

        service.create_or_update(payload_numeric_org)
        contact = Contact.last
        expect(contact.additional_attributes['company_name']).to eq('API Fetched Corp')
      end
    end
  end
end
