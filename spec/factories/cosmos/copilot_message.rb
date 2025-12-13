FactoryBot.define do
  factory :cosmos_copilot_message, class: 'CopilotMessage' do
    account
    copilot_thread { association :cosmos_copilot_thread }
    message { { content: 'This is a test message' } }
    message_type { 0 }
  end
end
