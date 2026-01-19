# app/services/evolution/message_status_service.rb
class Evolution::MessageStatusService
  include Evolution::StatusUpdate

  pattr_initialize [:inbox!, :params!]

  STATUS_MAP = {
    'SERVER_ACK' => 'sent',
    'SENT' => 'sent',
    'DELIVERY_ACK' => 'delivered',
    'DELIVERED' => 'delivered',
    'READ' => 'read',
    'SEEN' => 'read',
    'FAILED' => 'failed',
    'ERROR' => 'failed'
  }.freeze

  STATUS_RANK = { 'sent' => 0, 'delivered' => 1, 'read' => 2, 'failed' => 3 }.freeze

  def perform
    return if inbox.blank?
    return unless supported_status?

    msg = message
    return if msg.blank?

    new_status = normalised_status
    return if regression?(msg.status, new_status)
    return false unless valid_status_transition?(msg, new_status)

    update_message_status!(
      message: msg,
      status: new_status,
      external_error: (error_occurred? ? external_error : nil)
    )

    Rails.logger.info "[Evolution Message Update] msg: #{msg} status:#{new_status}"
    msg
  end

  private

  def supported_status?
    STATUS_MAP.key?(params[:status].to_s.upcase)
  end

  def normalised_status
    STATUS_MAP[params[:status].to_s.upcase] || 'sent'
  end

  def error_occurred?
    %w[FAILED ERROR].include?(params[:status].to_s.upcase)
  end

  def regression?(current, incoming)
    # nunca regredir (ex.: read -> delivered), mas permitir sobrescrever com failed
    return false if incoming == 'failed'
    return false if current.blank?

    cur_rank = STATUS_RANK[current]
    inc_rank = STATUS_RANK[incoming]
    cur_rank && inc_rank && inc_rank < cur_rank
  end

  def external_error
    code = params[:error_code] || params[:errorCode] || params.dig(:error, :code)
    msg  = params[:error_message] || params[:errorMessage] || params.dig(:error, :message)

    if code && msg
      "#{code} - #{msg}"
    elsif code
      I18n.t('conversations.messages.delivery_status.error_code', error_code: code)
    else
      msg
    end
  end

  def message
    key = params[:keyId].presence ||
          params[:messageId].presence ||
          params[:id].presence ||
          params[:key_id].presence
    return if key.blank?

    inbox.messages.outgoing.find_by(source_id: key)
  end
end
