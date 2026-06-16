# frozen_string_literal: true

class Evolution::UpdateMessageService
  pattr_initialize [:channel!, :message!]

  def perform
    Rails.logger.info(
      "[Evolution::UpdateMessageService] Message editing is not supported by the Evolution API. " \
      "msg=#{message.id} channel=#{channel.id}"
    )
  end
end
