class Companies::BaseExportService
  STANDARD_COLUMNS = %w[
    id name domain description contacts_count last_activity_at created_at
  ].freeze

  def initialize(account, params = {})
    @account = account
    @params = params || {}
  end

  private

  def headers
    @headers ||= STANDARD_COLUMNS + custom_attr_definitions.map { |d| d[:display_name] }
  end

  def custom_attr_definitions
    @custom_attr_definitions ||=
      @account.custom_attribute_definitions
              .where(attribute_model: 'company_attribute')
              .pluck(:attribute_key, :attribute_display_name)
              .map { |key, name| { key: key, display_name: name } }
  end

  def companies
    @companies ||= begin
      scope = @account.companies
      scope = scope.search_by_name_or_domain(@params[:search]) if @params[:search].present?
      scope.to_a
    end
  end

  def value_for(company, header)
    custom_def = custom_attr_definitions.find { |d| d[:display_name] == header }
    if custom_def
      company.custom_attributes[custom_def[:key]]
    else
      company.public_send(header)
    end
  end

  def rows
    companies.map do |company|
      headers.map { |header| value_for(company, header) }
    end
  end
end
