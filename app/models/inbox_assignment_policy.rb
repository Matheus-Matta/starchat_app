# == Schema Information
#
# Table name: inbox_assignment_policies
#
#  id                                   :bigint           not null, primary key
#  equal_distribution_balance_threshold :integer          default(20), not null
#  equal_distribution_enabled           :boolean          default(FALSE), not null
#  equal_distribution_window_hours      :integer          default(24), not null
#  created_at                           :datetime         not null
#  updated_at                           :datetime         not null
#  assignment_policy_id                 :bigint           not null
#  inbox_id                             :bigint           not null
#
# Indexes
#
#  index_inbox_assignment_policies_on_assignment_policy_id  (assignment_policy_id)
#  index_inbox_assignment_policies_on_inbox_id              (inbox_id) UNIQUE
#
class InboxAssignmentPolicy < ApplicationRecord
  belongs_to :inbox
  belongs_to :assignment_policy

  validates :inbox_id, uniqueness: true
  validates :equal_distribution_window_hours,
            numericality: { greater_than: 0 },
            if: :equal_distribution_enabled?
  validates :equal_distribution_balance_threshold,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 },
            if: :equal_distribution_enabled?
end
