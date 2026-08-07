class MessageContentPresenter < SimpleDelegator
  def webhook_content
    Messages::WebhookContentNormalizer.normalize(content_with_survey_link)
  end

  def outgoing_content
    Messages::MarkdownRendererService.new(
      content_with_survey_link,
      conversation.inbox.channel_type,
      conversation.inbox.channel
    ).render
  end

  private

  def content_with_survey_link
    if should_append_survey_link?
      survey_link = survey_url(conversation.uuid)
      custom_message = inbox.csat_config&.dig('message')
      custom_message.present? ? "#{custom_message} #{survey_link}" : I18n.t('conversations.survey.response', link: survey_link)
    else
      content
    end
  end

  def should_append_survey_link?
    input_csat? && !inbox.web_widget?
  end

  def survey_url(conversation_uuid)
    base_url = ENV['FRONTEND_URL_TESTE'].presence || ENV.fetch('FRONTEND_URL', nil)
    "#{base_url}/survey/responses/#{conversation_uuid}"
  end
end
