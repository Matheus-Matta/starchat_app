class DataImport::CompanyManager
  DIRECT_COLUMNS = %w[name domain description].freeze
  READONLY_COLUMNS = %w[id contacts_count created_at updated_at last_activity_at].freeze

  def initialize(account)
    @account = account
  end

  def build_company(params)
    company = find_or_initialize_company(params)
    update_company_attributes(params, company)
    company
  end

  def find_or_initialize_company(params)
    find_existing_company(params) || @account.companies.new
  end

  def find_existing_company(params)
    find_company_by_domain(params) || find_company_by_name(params)
  end

  def find_company_by_domain(params)
    return if params[:domain].blank?

    @account.companies.where('LOWER(domain) = ?', params[:domain].to_s.strip.downcase).first
  end

  def find_company_by_name(params)
    return if params[:name].blank?

    @account.companies.where('LOWER(name) = ?', params[:name].to_s.strip.downcase).first
  end

  private

  def update_company_attributes(params, company)
    company.custom_attributes ||= {}

    params.each do |key, value|
      next if READONLY_COLUMNS.include?(key.to_s)
      next if value.to_s.strip.blank?

      case key.to_s
      when *DIRECT_COLUMNS
        company.public_send(:"#{key}=", value)
      else
        custom_def = custom_attr_definitions.find { |d| d[:display_name].casecmp?(key.to_s) }
        company.custom_attributes[custom_def[:key]] = value if custom_def
      end
    end
  end

  def custom_attr_definitions
    @custom_attr_definitions ||=
      @account.custom_attribute_definitions
              .where(attribute_model: 'company_attribute')
              .pluck(:attribute_key, :attribute_display_name)
              .map { |key, name| { key: key, display_name: name } }
  end
end
