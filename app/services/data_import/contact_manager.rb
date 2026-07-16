class DataImport::ContactManager
  DIRECT_COLUMNS = %w[name middle_name last_name location country_code].freeze
  ADDITIONAL_ATTR_COLUMNS = %w[company_name city country].freeze
  SOCIAL_PROFILE_KEYS = %w[facebook github instagram linkedin twitter].freeze

  # Columns exported for reference only — never written back
  READONLY_COLUMNS = %w[
    id account_id created_at updated_at last_activity_at
    company_domain company_description
  ].freeze

  def initialize(account)
    @account = account
  end

  def build_contact(params)
    contact = find_or_initialize_contact(params)
    update_contact_attributes(params, contact)
    contact
  end

  def find_or_initialize_contact(params)
    contact = find_existing_contact(params)
    # Blank identifier/email must become nil, not "" — an empty string is a real value under
    # the account-scoped uniqueness index, so multiple blank rows (or a row and a pre-existing
    # contact with a legacy blank string) would collide with each other on insert.
    contact_params = params.slice(:email, :identifier, :phone_number).transform_values(&:presence)
    contact_params[:phone_number] = format_phone_number(contact_params[:phone_number]) if contact_params[:phone_number].present?
    contact ||= @account.contacts.new(contact_params)
    contact
  end

  def find_existing_contact(params)
    contact = find_contact_by_identifier(params)
    contact ||= find_contact_by_email(params)
    contact ||= find_contact_by_phone_number(params)

    update_contact_with_merged_attributes(params, contact) if contact.present? && contact.valid?
    contact
  end

  def find_contact_by_identifier(params)
    return if params[:identifier].blank?

    @account.contacts.find_by(identifier: params[:identifier])
  end

  def find_contact_by_email(params)
    return if params[:email].blank?

    @account.contacts.from_email(params[:email])
  end

  def find_contact_by_phone_number(params)
    return if params[:phone_number].blank?

    @account.contacts.find_by(phone_number: format_phone_number(params[:phone_number]))
  end

  def format_phone_number(phone_number)
    phone_number.start_with?('+') ? phone_number : "+#{phone_number}"
  end

  def update_contact_with_merged_attributes(params, contact)
    contact.identifier = params[:identifier] if params[:identifier].present?
    contact.email = params[:email] if params[:email].present?
    contact.phone_number = format_phone_number(params[:phone_number]) if params[:phone_number].present?
    update_contact_attributes(params, contact)
    contact.save
  end

  private

  def update_contact_attributes(params, contact)
    contact.additional_attributes ||= {}
    contact.custom_attributes ||= {}
    social_profiles = (contact.additional_attributes['social_profiles'] || {}).dup

    params.each do |key, value|
      next if READONLY_COLUMNS.include?(key.to_s)
      next if %w[identifier email phone_number labels inboxes].include?(key.to_s)
      next if value.to_s.strip.blank?
      # A contact that already has a name keeps it as-is on import — only its
      # additional/custom attributes get refreshed. Blank names still get filled in.
      next if key.to_s == 'name' && contact.persisted? && contact.name.present?

      case key.to_s
      when *DIRECT_COLUMNS
        contact.public_send(:"#{key}=", value)
      when 'contact_type'
        contact.contact_type = value if Contact.contact_types.key?(value.to_s)
      when 'blocked'
        contact.blocked = ActiveModel::Type::Boolean.new.cast(value)
      when 'company_id'
        contact.company_id = value if @account.companies.exists?(id: value)
      when *ADDITIONAL_ATTR_COLUMNS
        contact.additional_attributes[key.to_s] = value
      when *SOCIAL_PROFILE_KEYS
        social_profiles[key.to_s] = value
      else
        custom_def = custom_attr_definitions.find { |d| d[:display_name].casecmp?(key.to_s) }
        if custom_def
          contact.custom_attributes[custom_def[:key]] = value
        end
      end
    end

    contact.additional_attributes['social_profiles'] = social_profiles if social_profiles.present?
  end

  def custom_attr_definitions
    @custom_attr_definitions ||=
      @account.custom_attribute_definitions
              .where(attribute_model: 'contact_attribute')
              .pluck(:attribute_key, :attribute_display_name)
              .map { |key, name| { key: key, display_name: name } }
  end
end
