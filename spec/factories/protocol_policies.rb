FactoryBot.define do
  factory :protocol_policy do
    account { nil }
    name { "MyString" }
    prefix { "MyString" }
    scope { 1 }
    seq_padding { 1 }
    include_store_code { false }
    include_city_code { false }
    active { false }
  end
end
