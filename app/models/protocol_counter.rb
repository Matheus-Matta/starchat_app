# == Schema Information
#
# Table name: protocol_counters
#
#  id                 :bigint           not null, primary key
#  date               :date
#  last_seq           :integer          default(0), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  protocol_policy_id :bigint           not null
#
# Indexes
#
#  index_protocol_counters_on_protocol_policy_id           (protocol_policy_id)
#  index_protocol_counters_on_protocol_policy_id_and_date  (protocol_policy_id,date) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (protocol_policy_id => protocol_policies.id)
#
class ProtocolCounter < ApplicationRecord
  belongs_to :protocol_policy
end
