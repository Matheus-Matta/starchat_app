# frozen_string_literal: true

# AutoAssignment::PolicyAgentSelector
#
# Selects an agent from a filtered set of allowed inbox members using the
# inbox's assignment policy (equal-distribution / balanced / round-robin).
#
# Use this whenever the caller already has a pre-filtered list of candidates
# (e.g. only team members, only members with capacity) and wants the policy to
# pick among them — rather than using plain legacy round-robin blindly.
#
# All seletors expect InboxMember-like objects and return a User (or nil).
class AutoAssignment::PolicyAgentSelector
  def initialize(inbox:, allowed_agent_ids:)
    @inbox = inbox
    @allowed_agent_ids = Array(allowed_agent_ids).map(&:to_i)
  end

  # Returns a User or nil
  def find_assignee
    members = allowed_online_members
    return nil if members.empty?

    resolve_selector.select_agent(members)
  end

  private

  # ─── Candidate members ────────────────────────────────────────────────────

  def allowed_online_members
    online_ids = fetch_online_ids
    @inbox.inbox_members
          .joins(:user)
          .where(user_id: @allowed_agent_ids & online_ids)
          .includes(:user)
  end

  def fetch_online_ids
    available = OnlineStatusTracker.get_available_users(@inbox.account_id)
    available.select { |_, v| v == 'online' }.keys.map(&:to_i)
  end

  # ─── Selector resolution (mirrors Starchat::AutoAssignment::AssignmentService#resolve_selector) ──

  def resolve_selector
    if policy&.equal_distribution?
      policy_equal_distribution_selector
    elsif inbox_assignment_policy&.equal_distribution_enabled?
      inbox_equal_distribution_selector
    elsif policy&.balanced?
      Starchat::AutoAssignment::BalancedSelector.new(inbox: @inbox)
    else
      round_robin_selector
    end
  end

  def policy
    return nil unless @inbox.enable_auto_assignment?

    @policy ||= @inbox.assignment_policy
  end

  def inbox_assignment_policy
    @inbox_assignment_policy ||= @inbox.inbox_assignment_policy
  end

  def round_robin_selector
    @round_robin_selector ||= AutoAssignment::RoundRobinSelector.new(inbox: @inbox)
  end

  def policy_equal_distribution_selector
    Starchat::AutoAssignment::EqualDistributionSelector.new(
      inbox: @inbox,
      window_hours: policy.equal_distribution_window_hours,
      balance_threshold: policy.equal_distribution_balance_threshold,
      round_robin_fallback: round_robin_selector
    )
  end

  def inbox_equal_distribution_selector
    Starchat::AutoAssignment::EqualDistributionSelector.new(
      inbox: @inbox,
      window_hours: inbox_assignment_policy.equal_distribution_window_hours,
      balance_threshold: inbox_assignment_policy.equal_distribution_balance_threshold,
      round_robin_fallback: round_robin_selector
    )
  end
end
