FactoryBot.define do
  factory :cosmos_message_report, class: 'Cosmos::MessageReport' do
    report_reason { 'incorrect_information' }
    description { 'The generated citation is wrong.' }
    association :message
    association :user
  end
end
