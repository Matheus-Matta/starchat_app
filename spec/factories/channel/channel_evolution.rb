FactoryBot.define do
  factory :channel_evolution, class: 'Channel::Evolution' do
    account
    sequence(:instance_name) { |n| "evo-test-#{n}" }
    provider_config { {} }
    api_key { SecureRandom.hex(16) }

    after(:build) do |channel|
      channel.inbox ||= build(:inbox, account: channel.account, channel: channel)
    end
  end
end
