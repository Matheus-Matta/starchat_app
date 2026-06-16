class V2::Reports::AgentSummaryBuilder < V2::Reports::BaseSummaryBuilder
  pattr_initialize [:account!, :params!]

  def build
    load_data
    prepare_report
  end

  private

  attr_reader :conversations_count, :resolved_count,
              :avg_resolution_time, :avg_first_response_time, :avg_reply_time

  def prepare_report
    account.account_users.map do |account_user|
      build_agent_stats(account_user)
    end
  end

  def build_agent_stats(account_user)
    user_id = account_user.user_id
    {
      id: user_id,
      conversations_count: conversations_count[user_id] || 0,
      resolved_conversations_count: resolved_count[user_id] || 0,
      avg_resolution_time: avg_resolution_time[user_id],
      avg_first_response_time: avg_first_response_time[user_id],
      avg_reply_time: avg_reply_time[user_id],
      no_first_reply_count: no_first_reply_by_agent[user_id] || 0,
      waiting_count: waiting_by_agent[user_id] || 0
    }
  end

  def group_by_key
    :user_id
  end

  def no_first_reply_by_agent
    @no_first_reply_by_agent ||= account.conversations.open
                                        .where(first_reply_created_at: nil)
                                        .where.not(assignee_id: nil)
                                        .group(:assignee_id)
                                        .count
  end

  def waiting_by_agent
    @waiting_by_agent ||= account.conversations.open
                                 .where.not(waiting_since: nil)
                                 .where.not(assignee_id: nil)
                                 .group(:assignee_id)
                                 .count
  end
end
