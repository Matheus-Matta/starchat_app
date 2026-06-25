class V2::Reports::Timeseries::BaseTimeseriesBuilder
  include TimezoneHelper
  include DateRangeHelper

  DEFAULT_GROUP_BY = 'day'.freeze

  pattr_initialize :account, :params

  def scope
    return combined_entity_scope if combined_dimensions?
    return multi_entity_scope if multiple_ids?

    case dimension_type.to_sym
    when :account
      account
    when :inbox
      inbox
    when :agent
      user
    when :label
      label
    when :team
      team
    end
  end

  def data_source
    @data_source ||= Reports::DataSource.for(
      account: account,
      metric: params[:metric],
      dimension_type: dimension_type,
      dimension_id: params[:id],
      scope: scope,
      range: range,
      group_by: group_by,
      timezone_offset: params[:timezone_offset],
      business_hours: params[:business_hours],
      conversation_status: params[:status]
    )
  end

  def inbox
    @inbox ||= account.inboxes.find(params[:id])
  end

  def user
    @user ||= account.users.find(params[:id])
  end

  def label
    @label ||= account.labels.find(params[:id])
  end

  def team
    @team ||= account.teams.find(params[:id])
  end

  def group_by
    @group_by ||= %w[day week month year hour].include?(params[:group_by]) ? params[:group_by] : DEFAULT_GROUP_BY
  end

  def timezone
    @timezone ||= timezone_name_from_offset(params[:timezone_offset])
  end

  private

  def dimension_type
    (params[:type].presence || 'account').to_s
  end

  # Multiple ids means several agents/teams/inboxes/labels were selected at once
  # (Reports overview multi-select); their metrics are combined into a single series.
  def multiple_ids?
    params[:id].is_a?(Array) && dimension_type.to_sym != :account
  end

  def multi_entity_scope
    @multi_entity_scope ||= Reports::MultiEntityScope.new(account, dimension_type, params[:id])
  end

  # Combining several dimension types at once (e.g. Agent A + Team B) - used by the
  # Conversation report's filter, where types aren't mutually exclusive - combines
  # their conversations/messages/reporting_events with OR instead of summing one type.
  def combined_dimensions?
    [params[:agent_ids], params[:team_ids], params[:inbox_ids]].any?(&:present?)
  end

  def combined_entity_scope
    @combined_entity_scope ||= Reports::CombinedEntityScope.new(
      account,
      Array(params[:agent_ids]),
      Array(params[:team_ids]),
      Array(params[:inbox_ids])
    )
  end
end
