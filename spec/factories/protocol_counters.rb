FactoryBot.define do
  factory :protocol_counter do
    protocol_policy { nil }
    date { "2026-03-07" }
    last_seq { 1 }
  end
end
