# == Schema Information
#
# Table name: inbox_conversation_flows
#
#  id                   :bigint           not null, primary key
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  conversation_flow_id :bigint           not null
#  inbox_id             :bigint           not null
#
# Indexes
#
#  index_inbox_conversation_flows_on_conversation_flow_id  (conversation_flow_id)
#  index_inbox_conversation_flows_on_inbox_id              (inbox_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (conversation_flow_id => conversation_flows.id)
#  fk_rails_...  (inbox_id => inboxes.id)
#

class InboxConversationFlow < ApplicationRecord
  belongs_to :inbox
  belongs_to :conversation_flow

  validates :inbox_id, uniqueness: true
end
