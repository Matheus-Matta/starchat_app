FactoryBot.define do
  factory :cosmos_document, class: 'Cosmos::Document' do
    name { Faker::File.file_name }
    external_link { Faker::Internet.unique.url }
    content { Faker::Lorem.paragraphs.join("\n\n") }
    association :assistant, factory: :cosmos_assistant
    association :account
  end
end
