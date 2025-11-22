<<<<<<< HEAD
require 'rails_helper'
require Rails.root.join 'spec/mailers/administrator_notifications/shared/smtp_config_shared.rb'

RSpec.describe AdministratorNotifications::AccountNotificationMailer do
  include_context 'with smtp config'

  let!(:account) { create(:account) }
  let!(:admin) { create(:user, account: account, role: :administrator) }

  describe 'account_deletion' do
    let(:reason) { 'manual_deletion' }
    let(:mail) { described_class.with(account: account).account_deletion(account, reason) }
    let(:deletion_date) { 7.days.from_now.iso8601 }

    before do
      account.update!(custom_attributes: {
                        'marked_for_deletion_at' => deletion_date,
                        'marked_for_deletion_reason' => reason
                      })
    end

    it 'renders the subject' do
      expect(mail.subject).to eq('Your account has been marked for deletion')
    end

    it 'renders the receiver email' do
      expect(mail.to).to eq([admin.email])
    end

    it 'includes the account name in the email body' do
      expect(mail.body.encoded).to include(account.name)
    end

    it 'includes the deletion date in the email body' do
      expect(mail.body.encoded).to include(deletion_date)
    end

    it 'includes a link to cancel the deletion' do
      expect(mail.body.encoded).to include('Cancel Account Deletion')
    end

    context 'when reason is manual_deletion' do
      it 'includes the administrator message' do
        expect(mail.body.encoded).to include('This action was requested by one of the administrators of your account')
      end
    end

    context 'when reason is not manual_deletion' do
      let(:reason) { 'inactivity' }

      it 'includes the reason directly' do
        expect(mail.body.encoded).to include('Reason for deletion: inactivity')
      end
    end
  end

  describe 'contact_import_complete' do
    let!(:data_import) { build(:data_import, total_records: 10, processed_records: 8) }
    let(:mail) { described_class.with(account: account).contact_import_complete(data_import).deliver_now }

    it 'renders the subject' do
      expect(mail.subject).to eq('Contact Import Completed')
    end

    it 'renders the processed records' do
      expect(mail.body.encoded).to include('Number of records imported: 8')
      expect(mail.body.encoded).to include('Number of records failed: 2')
    end

    it 'renders the receiver email' do
      expect(mail.to).to eq([admin.email])
    end
  end

  describe 'contact_import_failed' do
    let(:mail) { described_class.with(account: account).contact_import_failed.deliver_now }

    it 'renders the subject' do
      expect(mail.subject).to eq('Contact Import Failed')
    end

    it 'renders the receiver email' do
      expect(mail.to).to eq([admin.email])
    end
  end

  describe 'contact_export_complete' do
    let!(:file_url) { 'http://test.com/test' }
    let(:mail) { described_class.with(account: account).contact_export_complete(file_url, admin.email).deliver_now }

    it 'renders the subject' do
      expect(mail.subject).to eq("Your contact's export file is available to download.")
    end

    it 'renders the receiver email' do
      expect(mail.to).to eq([admin.email])
    end
  end

  describe 'automation_rule_disabled' do
    let(:rule) { instance_double(AutomationRule, name: 'Test Rule') }
    let(:mail) { described_class.with(account: account).automation_rule_disabled(rule).deliver_now }

    it 'renders the subject' do
      expect(mail.subject).to eq('Automation rule disabled due to validation errors.')
    end

    it 'renders the receiver email' do
      expect(mail.to).to eq([admin.email])
    end

    it 'includes the rule name in the email body' do
      expect(mail.body.encoded).to include('Test Rule')
    end
  end
end
=======
require 'rails_helper'

RSpec.describe AdministratorNotifications::AccountNotificationMailer do
  let(:account) { create(:account, name: 'Test Account') }
  let(:mailer) { described_class.with(account: account) }
  let(:class_instance) { described_class.new }

  before do
    allow(described_class).to receive(:new).and_return(class_instance)
    allow(class_instance).to receive(:smtp_config_set_or_development?).and_return(true)
    account.custom_attributes['marked_for_deletion_at'] = 7.days.from_now.iso8601
    account.save!
  end

  describe '#account_deletion_user_initiated' do
    it 'sets the correct subject for user-initiated deletion' do
      mail = mailer.account_deletion_user_initiated(account, 'manual_deletion')
      expect(mail.subject).to eq('Your Chatwoot account deletion has been scheduled')
    end
  end

  describe '#account_deletion_for_inactivity' do
    it 'sets the correct subject for system-initiated deletion' do
      mail = mailer.account_deletion_for_inactivity(account, 'Account Inactive')
      expect(mail.subject).to eq('Your Chatwoot account is scheduled for deletion due to inactivity')
    end
  end

  describe '#format_deletion_date' do
    it 'formats a valid date string' do
      date_str = '2024-12-31T23:59:59Z'
      formatted = described_class.new.send(:format_deletion_date, date_str)
      expect(formatted).to eq('December 31, 2024')
    end

    it 'handles blank dates' do
      formatted = described_class.new.send(:format_deletion_date, nil)
      expect(formatted).to eq('Unknown')
    end

    it 'handles invalid dates' do
      formatted = described_class.new.send(:format_deletion_date, 'invalid-date')
      expect(formatted).to eq('Unknown')
    end
  end
end
>>>>>>> tags/v4.6.0
