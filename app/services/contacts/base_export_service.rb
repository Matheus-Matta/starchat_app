class Contacts::BaseExportService
  STANDARD_COLUMNS = %w[
    id name middle_name last_name email phone_number identifier
    location country_code contact_type blocked last_activity_at created_at
  ].freeze

  # company_name falls back to additional_attributes when no company is linked
  ADDITIONAL_ATTR_COLUMNS = %w[city country].freeze

  COMPANY_COLUMNS = %w[company_id company_name company_domain company_description].freeze

  SOCIAL_PROFILE_KEYS = %w[facebook github instagram linkedin twitter].freeze

  LABELS_COLUMN = 'labels'.freeze

  def initialize(account, user, params)
    @account = account
    @user = user
    @params = params || {}
  end

  private

  def headers
    @headers ||= begin
      cols = STANDARD_COLUMNS.dup
      cols += COMPANY_COLUMNS
      cols += ADDITIONAL_ATTR_COLUMNS
      cols += SOCIAL_PROFILE_KEYS
      cols << LABELS_COLUMN
      cols += custom_attr_definitions.map { |d| d[:display_name] }
      cols
    end
  end

  def custom_attr_definitions
    @custom_attr_definitions ||=
      @account.custom_attribute_definitions
              .where(attribute_model: 'contact_attribute')
              .pluck(:attribute_key, :attribute_display_name)
              .map { |key, name| { key: key, display_name: name } }
  end

  def contacts
    @contacts ||= begin
      scope = if @params[:payload].present? && @params[:payload].any?
                ::Contacts::FilterService.new(@account, @user, @params).perform[:contacts]
              elsif @params[:label].present?
                @account.contacts
                        .resolved_contacts(use_crm_v2: @account.feature_enabled?('crm_v2'))
                        .tagged_with(@params[:label], any: true)
              else
                @account.contacts.resolved_contacts(use_crm_v2: @account.feature_enabled?('crm_v2'))
              end
      scope.includes(:company).to_a
    end
  end

  def preload_labels
    @labels_by_contact_id ||= begin
      contact_ids = contacts.map(&:id)
      result = Hash.new { |h, k| h[k] = [] }
      return result if contact_ids.blank?

      approved = @account.labels.pluck(:title)
      ActsAsTaggableOn::Tagging
        .joins(:tag)
        .where(context: LABELS_COLUMN, taggable_type: 'Contact', taggable_id: contact_ids)
        .where(tags: { name: approved })
        .pluck(:taggable_id, 'tags.name')
        .each { |id, label| result[id] << label }
      result
    end
  end

  def value_for(contact, header)
    case header
    when 'company_id'
      contact.company_id
    when 'company_name'
      contact.company&.name || contact.additional_attributes['company_name']
    when 'company_domain'
      contact.company&.domain
    when 'company_description'
      contact.company&.description
    when *ADDITIONAL_ATTR_COLUMNS
      contact.additional_attributes[header]
    when *SOCIAL_PROFILE_KEYS
      contact.additional_attributes.dig('social_profiles', header)
    when LABELS_COLUMN
      preload_labels.fetch(contact.id, []).join(', ')
    else
      custom_def = custom_attr_definitions.find { |d| d[:display_name] == header }
      if custom_def
        contact.custom_attributes[custom_def[:key]]
      else
        contact.public_send(header)
      end
    end
  end

  def rows
    contacts.map do |contact|
      headers.map { |header| value_for(contact, header) }
    end
  end
end
