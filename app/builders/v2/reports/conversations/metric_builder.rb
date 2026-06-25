class V2::Reports::Conversations::MetricBuilder < V2::Reports::Conversations::BaseReportBuilder
  def summary
    {
      conversations_count: count('conversations_count'),
      unique_contacts_count: count('unique_contacts_count'),
      status_open_count: count('status_open_count'),
      status_resolved_count: count('status_resolved_count'),
      status_snoozed_count: count('status_snoozed_count'),
      status_pending_count: count('status_pending_count'),
      attendances_count: count('attendances_count'),
      incoming_messages_count: count('incoming_messages_count'),
      outgoing_messages_count: count('outgoing_messages_count'),
      avg_first_response_time: count('avg_first_response_time'),
      avg_resolution_time: count('avg_resolution_time'),
      resolutions_count: count('resolutions_count'),
      reply_time: count('reply_time'),
      no_first_reply_count: count('no_first_reply_count'),
      waiting_count: count('waiting_count')
    }
  end

  def bot_summary
    {
      bot_resolutions_count: count('bot_resolutions_count'),
      bot_handoffs_count: count('bot_handoffs_count')
    }
  end

  private

  def count(metric)
    klass = builder_class(metric)
    return 0 unless klass

    klass.new(account, builder_params(metric)).aggregate_value
  end

  def builder_params(metric)
    params.merge({ metric: metric })
  end
end
