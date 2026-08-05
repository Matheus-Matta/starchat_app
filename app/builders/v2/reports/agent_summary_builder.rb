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
      waiting_count: waiting_by_agent[user_id] || 0,
      csat_score: csat_score_by_agent[user_id],
      sla_hit_rate: sla_hit_rate_by_agent[user_id]
    }
  end

  def group_by_key
    :user_id
  end

  def no_first_reply_by_agent
    @no_first_reply_by_agent ||= conversations_in_range.open
                                                        .where(first_reply_created_at: nil)
                                                        .where.not(assignee_id: nil)
                                                        .group(:assignee_id)
                                                        .count
  end

  def waiting_by_agent
    @waiting_by_agent ||= conversations_in_range.open
                                                 .where.not(waiting_since: nil)
                                                 .where.not(assignee_id: nil)
                                                 .group(:assignee_id)
                                                 .count
  end

  # `no_first_reply_count`/`waiting_count` used to ignore params[:since]/params[:until]
  # entirely, so they kept counting conversations created outside the selected report
  # period even though every other column on this table (conversations_count, avg
  # times, resolutions_count) is scoped to that period. Applying the same `range` here
  # keeps the whole row consistent with the period the user picked.
  def conversations_in_range
    return account.conversations if range.blank?

    account.conversations.where(created_at: range)
  end

  # Same formula as the CSAT report (positive responses / total responses * 100),
  # see app/controllers/api/v1/accounts/csat_survey_responses_controller.rb and
  # app/javascript/dashboard/store/modules/csat.js#getSatisfactionScore.
  def csat_responses_in_range
    @csat_responses_in_range ||= account.csat_survey_responses.filter_by_created_at(range)
  end

  def csat_totals_by_agent
    @csat_totals_by_agent ||= csat_responses_in_range.group(:assigned_agent_id).count
  end

  def csat_positive_by_agent
    @csat_positive_by_agent ||= csat_responses_in_range.where(rating: [4, 5]).group(:assigned_agent_id).count
  end

  def csat_score_by_agent
    @csat_score_by_agent ||= csat_totals_by_agent.each_with_object({}) do |(agent_id, total), scores|
      next if agent_id.blank?

      scores[agent_id] = ((csat_positive_by_agent[agent_id].to_i * 100.0) / total).round(2)
    end
  end

  # Same formula as the SLA report's hit rate (see
  # starchat/app/controllers/api/v1/accounts/applied_slas_controller.rb), but per
  # agent instead of account-wide, and nil (not "100%") when the agent has no SLAs
  # applied in the period, since there's nothing to report a rate on.
  def applied_slas_in_range
    @applied_slas_in_range ||= account.applied_slas.joins(:conversation).filter_by_date_range(range)
  end

  def sla_totals_by_agent
    @sla_totals_by_agent ||= applied_slas_in_range.group('conversations.assignee_id').count
  end

  def sla_misses_by_agent
    @sla_misses_by_agent ||= applied_slas_in_range.missed.group('conversations.assignee_id').count
  end

  def sla_hit_rate_by_agent
    @sla_hit_rate_by_agent ||= sla_totals_by_agent.each_with_object({}) do |(agent_id, total), rates|
      next if agent_id.blank?

      misses = sla_misses_by_agent[agent_id].to_i
      rates[agent_id] = (((total - misses) / total.to_f) * 100).round(2)
    end
  end
end
