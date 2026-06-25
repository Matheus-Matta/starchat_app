require 'rails_helper'

RSpec.describe Contacts::ExportCsvService do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:contact) { create(:contact, :with_email, account: account) }

  def csv_row_for(contact)
    csv_content = described_class.new(account, user, {}).generate.force_encoding('UTF-8').delete_prefix("\xEF\xBB\xBF")
    csv_data = CSV.parse(csv_content, headers: true)
    csv_data.find { |row| row['id'].to_i == contact.id }
  end

  it 'includes an inboxes column' do
    csv_content = described_class.new(account, user, {}).generate.force_encoding('UTF-8').delete_prefix("\xEF\xBB\xBF")
    headers = CSV.parse(csv_content, headers: true).headers

    expect(headers).to include('inboxes')
  end

  it 'lists the names of every inbox linked to the contact, comma separated' do
    inbox_one = create(:inbox, account: account, name: 'Support')
    inbox_two = create(:inbox, account: account, name: 'Sales')
    create(:contact_inbox, contact: contact, inbox: inbox_one)
    create(:contact_inbox, contact: contact, inbox: inbox_two)

    row = csv_row_for(contact)

    expect(row['inboxes'].split(', ')).to contain_exactly('Support', 'Sales')
  end

  it 'leaves the inboxes column blank when the contact has no linked inbox' do
    row = csv_row_for(contact)

    expect(row['inboxes']).to eq('')
  end
end
