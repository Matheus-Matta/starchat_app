class Whatsapp::TemplateAnalyticsService
  # status enum: { sent: 0, delivered: 1, read: 2, failed: 3 }
  DELIVERED_STATUSES = [1, 2].freeze
  READ_STATUS        = 2
  FAILED_STATUS      = 3

  def initialize(account:, inbox_id:, since:, until_date:)
    @account    = account
    @inbox_id   = inbox_id
    @since      = Time.at(since.to_i)
    @until_date = Time.at(until_date.to_i)
  end

  def perform
    base_scope.map do |row|
      total     = row.total.to_i
      sent      = row.sent_count.to_i
      delivered = row.delivered_count.to_i
      read      = row.read_count.to_i
      failed    = row.failed_count.to_i

      {
        template_name:  row.template_name,
        language:       row.language || '',
        total:          total,
        sent:           sent,
        delivered:      delivered,
        read:           read,
        failed:         failed,
        delivery_rate:  percentage(delivered, sent),
        read_rate:      percentage(read, sent)
      }
    end
  end

  private

  def base_scope
    @account.messages
            .where(inbox_id: @inbox_id, message_type: :template)
            .where(created_at: @since..@until_date)
            .where("additional_attributes -> 'template_params' ->> 'name' IS NOT NULL")
            .select(select_sql)
            .group(group_sql)
            .reorder(Arel.sql('COUNT(*) DESC'))
  end

  def select_sql
    <<~SQL.squish
      additional_attributes -> 'template_params' ->> 'name'     AS template_name,
      additional_attributes -> 'template_params' ->> 'language' AS language,
      COUNT(*)                                                    AS total,
      SUM(CASE WHEN status NOT IN (#{FAILED_STATUS}) THEN 1 ELSE 0 END) AS sent_count,
      SUM(CASE WHEN status IN (#{DELIVERED_STATUSES.join(',')}) THEN 1 ELSE 0 END) AS delivered_count,
      SUM(CASE WHEN status = #{READ_STATUS} THEN 1 ELSE 0 END)  AS read_count,
      SUM(CASE WHEN status = #{FAILED_STATUS} THEN 1 ELSE 0 END) AS failed_count
    SQL
  end

  def group_sql
    <<~SQL.squish
      additional_attributes -> 'template_params' ->> 'name',
      additional_attributes -> 'template_params' ->> 'language'
    SQL
  end

  def percentage(numerator, denominator)
    return 0.0 if denominator.zero?

    (numerator.to_f / denominator * 100).round(1)
  end
end
