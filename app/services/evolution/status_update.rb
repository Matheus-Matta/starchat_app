# app/services/messages/status_update.rb
module Evolution
  module StatusUpdate
    def valid_status_transition?(message, status)
      return false unless Message.statuses.key?(status)
      return false if message.read? && status == 'delivered'
      true
    end

    def update_message_status!(message:, status:, external_error: nil)
      return unless valid_status_transition?(message, status)

      message.with_lock do
        message.update!(
          status: status,
          external_error: (status == 'failed' ? external_error : nil)
        )
      end

      Rails.logger.info "[Evolution Message Update] id=#{message.id} status=#{message.status}"
    end
  end
end
