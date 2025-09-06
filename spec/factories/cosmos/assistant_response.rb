FactoryBot.define do
  factory :cosmos_assistant_response, class: 'Cosmos::AssistantResponse' do
    association :assistant, factory: :cosmos_assistant
    association :account
    sequence(:question) { |n| "Test question #{n}?" }
    sequence(:answer) { |n| "Test answer #{n}" }
    embedding { Array.new(1536) { rand(-1.0..1.0) } }

    trait :with_document do
      association :document, factory: :cosmos_document
    end
  end
end
