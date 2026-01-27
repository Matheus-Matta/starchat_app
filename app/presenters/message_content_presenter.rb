class MessageContentPresenter < SimpleDelegator
  def outgoing_content
    content_to_send = if should_append_survey_link?
                        survey_link = survey_url(conversation.uuid)
                        custom_message = inbox.csat_config&.dig('message')
                        custom_message.present? ? "#{custom_message} #{survey_link}" : I18n.t('conversations.survey.response', link: survey_link)
                      else
                        content
                      end

    Messages::MarkdownRendererService.new(
      content_to_send,
      conversation.inbox.channel_type,
      conversation.inbox.channel
    ).render
  end

  private

  def should_append_survey_link?
    input_csat? && !inbox.web_widget?
  end

  def survey_url(conversation_uuid)
    base_url = ENV['FRONTEND_URL_TESTE'].presence || ENV.fetch('FRONTEND_URL', nil)
    "#{base_url}/survey/responses/#{conversation_uuid}"
  end
end
