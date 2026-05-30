class Llm::BaseAiService
  private

  def sanitize_json_response(content)
    return nil if content.nil?

    content.gsub(/\A```(?:json)?\s*/m, '').gsub(/\s*```\z/m, '').strip
  end
end
