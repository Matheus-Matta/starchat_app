# == Schema Information
#
# Table name: contact_responsible_agents
#
#  id         :bigint           not null, primary key
#  contact_id :bigint           not null
#  user_id    :bigint           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_contact_responsible_agents_on_contact_id              (contact_id)
#  index_contact_responsible_agents_on_contact_id_and_user_id  (contact_id,user_id) UNIQUE
#  index_contact_responsible_agents_on_user_id                 (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (contact_id => contacts.id)
#  fk_rails_...  (user_id => users.id)
#
class ContactResponsibleAgent < ApplicationRecord
  belongs_to :contact
  belongs_to :user

  validates :user_id, uniqueness: { scope: :contact_id }
  validate :user_belongs_to_contact_account

  private

  def user_belongs_to_contact_account
    return if user_id.blank? || contact_id.blank?
    return if contact.account.users.exists?(id: user_id)

    errors.add(:user_id, 'is invalid: agent does not belong to the contact account')
  end
end
