module Api::V2::Accounts::ReportsHelper
  include TimezoneHelper

  # Date format per locale for CSV/XLSX exports - pt_BR and en for now.
  REPORT_DATE_FORMATS = {
    'pt_BR' => '%d/%m/%Y'
  }.freeze
  REPORT_DATE_FORMAT_DEFAULT = '%m/%d/%Y'.freeze

  def generate_agents_report
    entity_report_rows(V2::Reports::AgentSummaryBuilder, :agent, Current.account.users) do |agent|
      [agent.name]
    end
  end

  def generate_inboxes_report
    entity_report_rows(V2::Reports::InboxSummaryBuilder, :inbox, Current.account.inboxes) do |inbox|
      [inbox.name, inbox.channel&.name]
    end
  end

  def generate_teams_report
    entity_report_rows(V2::Reports::TeamSummaryBuilder, :team, Current.account.teams) do |team|
      [team.name]
    end
  end

  def generate_labels_report
    total_rows = build_label_rows(build_params(type: :label), total_row_label)

    daily_rows = daily_date_ranges.flat_map do |day|
      build_label_rows(build_params_for_day(type: :label, day: day), format_report_date(day[:date]))
    end

    total_rows + daily_rows
  end

  def generate_conversations_summary_report
    total_rows = [[total_row_label] + conversations_summary_metrics(build_params(type: :account))]

    daily_rows = daily_date_ranges.map do |day|
      [format_report_date(day[:date])] + conversations_summary_metrics(build_params_for_day(type: :account, day: day))
    end

    total_rows + daily_rows
  end

  private

  # Builds the "Total for the period" rows plus one row per (entity, day) so every
  # report with a date filter shows the period total up top and a daily breakdown below.
  def entity_report_rows(builder_class, type, entities, &entity_columns)
    total_reports = builder_class.new(account: Current.account, params: build_params(type: type)).build
    total_rows = entities.map { |entity| build_entity_row(total_row_label, entity, total_reports, &entity_columns) }

    daily_rows = daily_date_ranges.flat_map do |day|
      day_reports = builder_class.new(account: Current.account, params: build_params_for_day(type: type, day: day)).build
      entities.map { |entity| build_entity_row(format_report_date(day[:date]), entity, day_reports, &entity_columns) }
    end

    total_rows + daily_rows
  end

  def build_entity_row(date_label, entity, reports, &entity_columns)
    report = reports.find { |r| r[:id] == entity.id }
    [date_label] + entity_columns.call(entity) + generate_readable_report_metrics(report)
  end

  def build_label_rows(label_params, date_label)
    V2::Reports::LabelSummaryBuilder.new(account: Current.account, params: label_params).build.map do |report|
      [date_label, report[:name]] + generate_readable_report_metrics(report)
    end
  end

  def conversations_summary_metrics(metric_params)
    summary = V2::Reports::Conversations::MetricBuilder.new(Current.account, metric_params).summary

    [
      summary[:conversations_count],
      summary[:incoming_messages_count],
      summary[:outgoing_messages_count],
      Reports::TimeFormatPresenter.new(summary[:avg_first_response_time]).format,
      Reports::TimeFormatPresenter.new(summary[:avg_resolution_time]).format,
      summary[:resolutions_count],
      Reports::TimeFormatPresenter.new(summary[:reply_time]).format
    ]
  end

  def total_row_label
    I18n.t('reports.total_row_label')
  end

  def format_report_date(date)
    date.strftime(REPORT_DATE_FORMATS.fetch(I18n.locale.to_s, REPORT_DATE_FORMAT_DEFAULT))
  end

  # Splits the requested since/until range into one bucket per calendar day, in the
  # report's timezone, so daily CSV/XLSX rows line up with the dashboard's day-bucketed charts.
  def daily_date_ranges
    return [] if params[:since].blank? || params[:until].blank?

    zone = ActiveSupport::TimeZone[timezone_name_from_offset(params[:timezone_offset])] || Time.zone
    since_time = zone.at(params[:since].to_i)
    until_time = zone.at(params[:until].to_i)

    (since_time.to_date..until_time.to_date).map do |date|
      day_start = zone.local(date.year, date.month, date.day).beginning_of_day
      day_end = [day_start.end_of_day, until_time].min

      {
        date: date,
        since: [day_start, since_time].max.to_i.to_s,
        until: day_end.to_i.to_s
      }
    end
  end

  def build_params_for_day(base_params)
    raise ArgumentError, 'day is required' unless base_params[:day]

    day = base_params[:day]
    build_params(base_params.except(:day)).merge(since: day[:since], until: day[:until])
  end

  def build_params(base_params)
    base_params.merge(
      {
        since: params[:since],
        until: params[:until],
        business_hours: ActiveModel::Type::Boolean.new.cast(params[:business_hours])
      }
    )
  end

  def report_builder(report_params)
    V2::ReportBuilder.new(Current.account, build_params(report_params))
  end

  def generate_readable_report_metrics(report)
    [
      report[:conversations_count],
      Reports::TimeFormatPresenter.new(report[:avg_first_response_time]).format,
      Reports::TimeFormatPresenter.new(report[:avg_resolution_time]).format,
      Reports::TimeFormatPresenter.new(report[:avg_reply_time]).format,
      report[:resolved_conversations_count]
    ]
  end
end
