class Cosmos::Tools::Copilot::SearchArticlesService < Cosmos::Tools::BaseService
  def name
    'search_articles'
  end

  def description
    'Search articles based on parameters'
  end

  def parameters
    {
      type: 'object',
      properties: properties,
      required: ['query']
    }
  end

  def execute(arguments)
    query = arguments['query']
    category_id = arguments['category_id']
    status = arguments['status']

    Rails.logger.info "#{self.class.name}: Query: #{query}, Category ID: #{category_id}, Status: #{status}"

    return 'Missing required parameters' if query.blank?

    articles = fetch_articles(query, category_id, status)

    return 'No articles found' unless articles.exists?

    total_count = articles.count
    articles = articles.limit(100)

    <<~RESPONSE
      #{total_count > 100 ? "Found #{total_count} articles (showing first 100)" : "Total number of articles: #{total_count}"}
      #{articles.map(&:to_llm_text).join("\n---\n")}
    RESPONSE
  end

  def active?
    return false if @user.blank?

    account_user = AccountUser.find_by(account_id: @assistant.account_id, user_id: @user.id)
    return false if account_user.nil?
    return account_user.custom_role&.permissions&.include?('knowledge_base_manage') || false if account_user.custom_role_id.present?

    true
  end

  private

  def fetch_articles(query, category_id, status)
    articles = Article.where(account_id: @assistant.account_id)
    articles = articles.where('title ILIKE :query OR content ILIKE :query', query: "%#{query}%") if query.present?
    articles = articles.where(category_id: category_id) if category_id.present?
    articles = articles.where(status: status) if status.present?
    articles
  end

  def properties
    {
      query: {
        type: 'string',
        description: 'Search articles by title or content (partial match)'
      },
      category_id: {
        type: 'number',
        description: 'Filter articles by category ID'
      },
      status: {
        type: 'string',
        enum: %w[draft published archived],
        description: 'Filter articles by status'
      }
    }
  end
end
