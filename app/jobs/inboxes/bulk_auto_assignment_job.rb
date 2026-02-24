class Inboxes::BulkAutoAssignmentJob < ApplicationJob
  queue_as :scheduled_jobs
  include BillingHelper

  def perform
    Account.feature_assignment_v2.find_each do |account|
      if should_skip_auto_assignment?(account)
        Rails.logger.info("Skipping auto assignment for account #{account.id}")
        next
      end

      account.inboxes.where(enable_auto_assignment: true).find_each do |inbox|
        process_assignment(inbox)
      end
    end
  end

  private

  def process_assignment(inbox)
    if inbox.auto_assignment_v2_enabled?
      # Use the policy-aware bulk service (equal-distribution / balanced / round-robin)
      count = ::AutoAssignment::AssignmentService.new(inbox: inbox)
                                                 .perform_bulk_assignment(limit: Limits::AUTO_ASSIGNMENT_BULK_LIMIT)
      Rails.logger.info("[BulkAutoAssignment] inbox=#{inbox.id} assigned=#{count} (v2 policy)")
    else
      # Legacy path
      allowed_agent_ids = inbox.member_ids_with_assignment_capacity
      if allowed_agent_ids.blank?
        Rails.logger.info("No agents available to assign conversation to inbox #{inbox.id}")
        return
      end
      assign_conversations(inbox, allowed_agent_ids)
    end
  end

  def assign_conversations(inbox, allowed_agent_ids)
    unassigned_conversations = inbox.conversations.unassigned.open.limit(Limits::AUTO_ASSIGNMENT_BULK_LIMIT)
    unassigned_conversations.find_each do |conversation|
      ::AutoAssignment::AgentAssignmentService.new(
        conversation: conversation,
        allowed_agent_ids: allowed_agent_ids
      ).perform
      Rails.logger.info("Assigned conversation #{conversation.id} to agent #{allowed_agent_ids.first}")
    end
  end

  def should_skip_auto_assignment?(account)
    return false unless ChatwootApp.chatwoot_cloud?

    default_plan?(account)
  end
end
