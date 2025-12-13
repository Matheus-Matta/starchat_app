FactoryBot.define do
  factory :cosmos_copilot_thread, class: 'CopilotThread' do
    account
    user
    title { Faker::Lorem.sentence }
    assistant { create(:cosmos_assistant, account: account) }
  end
end
