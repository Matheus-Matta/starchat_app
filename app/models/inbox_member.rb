# == Schema Information
#
# Table name: inbox_members
#
#  id         :integer          not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  inbox_id   :integer          not null
#  user_id    :integer          not null
#
# Indexes
#
#  index_inbox_members_on_inbox_id              (inbox_id)
#  index_inbox_members_on_inbox_id_and_user_id  (inbox_id,user_id) UNIQUE
#

class InboxMember < ApplicationRecord
  validates :inbox_id, presence: true
  validates :user_id, presence: true
  validates :user_id, uniqueness: { scope: :inbox_id }

  belongs_to :user
  belongs_to :inbox

  after_create :add_agent_to_round_robin
  after_destroy :remove_agent_from_round_robin
  after_commit :update_inbox_cache
  after_commit :dispatch_member_added_event, on: :create
  after_commit :dispatch_member_removed_event, on: :destroy

  private

  def add_agent_to_round_robin
    ::AutoAssignment::InboxRoundRobinService.new(inbox: inbox).add_agent_to_queue(user_id)
  end

  def remove_agent_from_round_robin
    ::AutoAssignment::InboxRoundRobinService.new(inbox: inbox).remove_agent_from_queue(user_id) if inbox.present?
  end

  def update_inbox_cache
    inbox&.update_account_cache
  end

  def dispatch_member_added_event
    return unless inbox.present? && user.present?

    Rails.configuration.dispatcher.dispatch(INBOX_MEMBER_ADDED, Time.zone.now, inbox: inbox, user: user)
  end

  def dispatch_member_removed_event
    return unless inbox.present? && user.present?

    Rails.configuration.dispatcher.dispatch(INBOX_MEMBER_REMOVED, Time.zone.now, inbox: inbox, user: user)
  end
end

InboxMember.include_mod_with('Audit::InboxMember')
