FactoryBot.define do
  factory :cosmos_agent_session, class: 'Cosmos::AgentSession' do
    account
    association :assistant, factory: :cosmos_assistant
    session_type { :assistant }
    subject { create(:conversation, account: account) }

    trait :copilot do
      session_type { :copilot }
      user
      subject { create(:cosmos_copilot_thread, account: account, user: user) }
    end
  end
end
