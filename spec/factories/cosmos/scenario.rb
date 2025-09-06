FactoryBot.define do
  factory :cosmos_scenario, class: 'Cosmos::Scenario' do
    sequence(:title) { |n| "Scenario #{n}" }
    description { 'Test scenario description' }
    instruction { 'Test scenario instruction for the assistant to follow' }
    tools { [] }
    enabled { true }
    association :assistant, factory: :cosmos_assistant
    association :account
  end
end
