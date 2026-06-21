# == Schema Information
#
# Table name: campaign_contacts
#
#  id             :bigint           not null, primary key
#  status         :integer          default("pending"), not null
#  sent_at        :datetime
#  error_message  :text
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  campaign_id    :bigint           not null
#  contact_id     :bigint           not null
#
# Indexes
#
#  index_campaign_contacts_on_campaign_id_and_contact_id  (campaign_id, contact_id) UNIQUE
#  index_campaign_contacts_on_campaign_id                 (campaign_id)
#  index_campaign_contacts_on_contact_id                  (contact_id)
#
class CampaignContact < ApplicationRecord
  belongs_to :campaign
  belongs_to :contact

  enum status: { pending: 0, sent: 1, failed: 2 }
end
