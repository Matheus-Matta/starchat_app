class Api::V2::Accounts::ReportsController < Api::V1::Accounts::BaseController
  include Api::V2::Accounts::ReportsHelper
  include Api::V2::Accounts::HeatmapHelper

  before_action :check_authorization

  def index
    builder = V2::Reports::Conversations::ReportBuilder.new(Current.account, report_params)
    data = builder.timeseries
    render json: data
  end

  def summary
    render json: build_summary(:summary)
  end

  def bot_summary
    render json: build_summary(:bot_summary)
  end

  def agents
    @report_data = generate_agents_report
    generate_csv('agents_report', 'api/v2/accounts/reports/agents')
  end

  def agent_conversations
    @agent = Current.account.users.find(params[:agent_id])
    report = V2::Reports::AgentConversationDetailBuilder.new(account: Current.account, agent: @agent, params: build_params(type: :agent)).build
    @rows = report[:rows]
    @totals = report[:totals]
    generate_csv('agent_conversations_report', 'api/v2/accounts/reports/agent_conversations')
  end

  def inboxes
    @report_data = generate_inboxes_report
    generate_csv('inboxes_report', 'api/v2/accounts/reports/inboxes')
  end

  def labels
    @report_data = generate_labels_report
    generate_csv('labels_report', 'api/v2/accounts/reports/labels')
  end

  def teams
    @report_data = generate_teams_report
    generate_csv('teams_report', 'api/v2/accounts/reports/teams')
  end

  def conversations_summary
    @report_data = generate_conversations_summary_report
    generate_csv('conversations_summary_report', 'api/v2/accounts/reports/conversations_summary')
  end

  def conversation_traffic
    @report_data = generate_conversations_heatmap_report
    timezone_offset = (params[:timezone_offset] || 0).to_f
    @timezone = ActiveSupport::TimeZone[timezone_offset]

    generate_csv('conversation_traffic_reports', 'api/v2/accounts/reports/conversation_traffic')
  end

  def conversations
    return head :unprocessable_entity if params[:type].blank?

    render json: conversation_metrics
  end

  def bot_metrics
    bot_metrics = V2::Reports::BotMetricsBuilder.new(Current.account, params).metrics
    render json: bot_metrics
  end

  def whatsapp_templates
    inbox = Current.account.inboxes.find_by(id: params[:inbox_id])
    return render json: { error: 'Inbox not found' }, status: :unprocessable_entity if inbox.nil?
    return render json: { error: 'Not a WhatsApp inbox' }, status: :unprocessable_entity unless inbox.channel_type == 'Channel::Whatsapp'

    data = Whatsapp::TemplateAnalyticsService.new(
      account:    Current.account,
      inbox_id:   inbox.id,
      since:      params[:since],
      until_date: params[:until]
    ).perform

    render json: { data: data }
  end

  def first_response_time_distribution
    since_time = Time.zone.at(params[:since].to_i)
    until_time = Time.zone.at(params[:until].to_i)

    events = ReportingEvent
             .where(account: Current.account, name: 'first_response')
             .where(created_at: since_time..until_time)
             .joins('JOIN inboxes ON inboxes.id = reporting_events.inbox_id')
             .select('reporting_events.value, inboxes.channel_type')

    buckets = { '0-1h' => 0..3600, '1-4h' => 3601..14_400, '4-8h' => 14_401..28_800,
                '8-24h' => 28_801..86_400, '24h+' => 86_401..Float::INFINITY }

    result = events.each_with_object({}) do |event, hash|
      channel = event.channel_type
      hash[channel] ||= buckets.keys.index_with(0)
      bucket = buckets.find { |_k, range| range.cover?(event.value) }&.first
      hash[channel][bucket] += 1 if bucket
    end

    render json: result
  end

  def outgoing_messages_count
    valid_groups = %w[agent team inbox label]
    group_by = params[:group_by]
    return head :unprocessable_entity unless valid_groups.include?(group_by)

    since_time = Time.zone.at(params[:since].to_i)
    until_time = Time.zone.at(params[:until].to_i)

    render json: outgoing_messages_for(group_by, since_time, until_time)
  end

  def inbox_label_matrix
    since_time = params[:since].present? ? Time.zone.at(params[:since].to_i) : 1.month.ago
    until_time = params[:until].present? ? Time.zone.at(params[:until].to_i) : Time.current

    inboxes = Current.account.inboxes
    inboxes = inboxes.where(id: params[:inbox_ids]) if params[:inbox_ids].present?

    labels = Current.account.labels
    labels = labels.where(id: params[:label_ids]) if params[:label_ids].present?

    conversations = Current.account.conversations.where(inbox_id: inboxes.select(:id), created_at: since_time..until_time)

    matrix = conversations.joins(:taggings)
                          .joins("JOIN tags ON tags.id = taggings.tag_id AND taggings.context = 'labels'")
                          .where(tags: { name: labels.select(:title) })
                          .group(:inbox_id, 'tags.id')
                          .count
                          .map do |(inbox_id, label_id), count|
                            { inbox_id: inbox_id, label_id: label_id, count: count }
                          end

    render json: {
      inboxes: inboxes.as_json(only: [:id, :name]),
      labels: labels.as_json(only: [:id, :title]),
      matrix: matrix
    }
  end

  private

  def generate_csv(filename, template)
    response.headers['Content-Type'] = 'text/csv'
    response.headers['Content-Disposition'] = "attachment; filename=#{filename}.csv"
    render layout: false, template: template, formats: [:csv]
  end

  def check_authorization
    authorize :report, :view?
  end

  def common_params
    {
      type: params[:type].to_sym,
      id: params[:id],
      agent_ids: params[:agent_ids],
      team_ids: params[:team_ids],
      inbox_ids: params[:inbox_ids],
      group_by: params[:group_by],
      business_hours: ActiveModel::Type::Boolean.new.cast(params[:business_hours]),
      status: params[:status].presence
    }
  end

  def current_summary_params
    common_params.merge({
                          since: range[:current][:since],
                          until: range[:current][:until],
                          timezone_offset: params[:timezone_offset]
                        })
  end

  def previous_summary_params
    common_params.merge({
                          since: range[:previous][:since],
                          until: range[:previous][:until],
                          timezone_offset: params[:timezone_offset]
                        })
  end

  def report_params
    common_params.merge({
                          metric: params[:metric],
                          since: params[:since],
                          until: params[:until],
                          timezone_offset: params[:timezone_offset]
                        })
  end

  def conversation_params
    {
      type: params[:type].to_sym,
      user_id: params[:user_id],
      page: params[:page].presence || 1
    }
  end

  def range
    {
      current: {
        since: params[:since],
        until: params[:until]
      },
      previous: {
        since: (params[:since].to_i - (params[:until].to_i - params[:since].to_i)).to_s,
        until: params[:since]
      }
    }
  end

  def build_summary(method)
    builder = V2::Reports::Conversations::MetricBuilder
    current_summary = builder.new(Current.account, current_summary_params).send(method)
    previous_summary = builder.new(Current.account, previous_summary_params).send(method)
    current_summary.merge(previous: previous_summary)
  end

  def conversation_metrics
    V2::ReportBuilder.new(Current.account, conversation_params).conversation_metrics
  end

  def outgoing_messages_for(group_by, since_time, until_time)
    base = Current.account.messages
                  .reorder(nil)
                  .where(message_type: :outgoing, created_at: since_time..until_time)

    case group_by
    when 'agent'
      base.where(sender_type: 'User')
          .group(:sender_id)
          .count
          .map do |user_id, count|
            user = User.find_by(id: user_id)
            next unless user

            { id: user_id, name: user.name, outgoing_messages_count: count }
          end.compact
    when 'team'
      base.joins(:conversation)
          .where.not(conversations: { team_id: nil })
          .group('conversations.team_id')
          .count
          .map do |team_id, count|
            team = Current.account.teams.find_by(id: team_id)
            next unless team

            { id: team_id, name: team.name, outgoing_messages_count: count }
          end.compact
    when 'inbox'
      base.group(:inbox_id)
          .count
          .map do |inbox_id, count|
            inbox = Current.account.inboxes.find_by(id: inbox_id)
            next unless inbox

            { id: inbox_id, name: inbox.name, outgoing_messages_count: count }
          end.compact
    when 'label'
      base.joins(conversation: :taggings)
          .joins("JOIN tags ON tags.id = taggings.tag_id AND taggings.context = 'labels'")
          .group('tags.id', 'tags.name')
          .count
          .map do |(tag_id, tag_name), count|
            label = Current.account.labels.find_by(title: tag_name)
            next unless label

            { id: label.id, name: tag_name, outgoing_messages_count: count }
          end.compact
    end
  end
end
