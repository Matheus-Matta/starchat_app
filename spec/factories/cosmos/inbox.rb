FactoryBot.define do
  factory :cosmos_inbox, class: 'CosmosInbox' do
    association :cosmos_assistant, factory: :cosmos_assistant
    association :inbox
  end
end
