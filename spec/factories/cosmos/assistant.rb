FactoryBot.define do
  factory :cosmos_assistant, class: 'Cosmos::Assistant' do
    sequence(:name) { |n| "Assistant #{n}" }
    description { 'Test description' }
    association :account
  end
end
