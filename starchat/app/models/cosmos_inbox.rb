# == Schema Information
#
# Table name: cosmos_inboxes
#
#  id                  :bigint           not null, primary key
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  cosmos_assistant_id :bigint           not null
#  inbox_id            :bigint           not null
#
# Indexes
#
#  index_cosmos_inboxes_on_cosmos_assistant_id               (cosmos_assistant_id)
#  index_cosmos_inboxes_on_cosmos_assistant_id_and_inbox_id  (cosmos_assistant_id,inbox_id) UNIQUE
#  index_cosmos_inboxes_on_inbox_id                          (inbox_id)
#
class CosmosInbox < ApplicationRecord
  belongs_to :cosmos_assistant, class_name: 'Cosmos::Assistant'
  belongs_to :inbox

  validates :inbox_id, uniqueness: true
end
