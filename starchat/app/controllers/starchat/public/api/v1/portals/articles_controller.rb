module Starchat::Public::Api::V1::Portals::ArticlesController
  private

  def search_articles
    return super unless @portal.account.feature_enabled?('help_center_embedding_search')
    return super if list_params[:query].blank?

    @articles = @articles.vector_search(list_params)
  rescue StandardError => e
    # Embedding search needs a working OpenAI configuration. If the key is missing,
    # invalid, or the provider is unreachable, fall back to the built-in text search
    # rather than 500ing the whole help center.
    Rails.logger.warn("[HelpCenter] embedding search unavailable, falling back to text search: #{e.class} #{e.message}")
    super
  end
end
