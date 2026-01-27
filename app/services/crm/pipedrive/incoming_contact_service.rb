class Crm::Pipedrive::IncomingContactService
  CACHE_EXPIRY = 1.minute
  DEFAULT_LABEL_COLOR = '#26292c'
  LABEL_TITLE = 'pipedrive'

  def initialize(account:)
    @account = account
    @hook = @account.hooks.find_by(app_id: 'pipedrive')
  end

  def create_or_update(data)
    return unless should_sync?
    return if recently_synced_from_chatwoot?(data['id'])

    contacts = find_or_create_contacts(data)
    contacts.each { |contact| sync_contact(contact, data) }
  end

  private

  def should_sync?
    client.present? && settings['sync_contacts']
  end

  def recently_synced_from_chatwoot?(pipedrive_id)
    Rails.cache.read("chatwoot_source_#{pipedrive_id}").present?
  end

  def client
    return nil unless @hook&.settings&.dig('api_token')
    @client ||= PipedriveClient.new(
      base_url: @hook.settings['pipedrive_url'],
      api_token: @hook.settings['api_token']
    )
  end

  def settings
    @settings ||= @hook.settings || {}
  end

  def sync_flags
    @sync_flags ||= {
      phone: settings['sync_phone'] != false,
      email: settings['sync_email'] != false,
      name: settings['sync_name'] != false,
      org: settings['sync_organization'] != false
    }
  end

  def find_or_create_contacts(data)
    email = extract_value(data['email'])
    phone = format_phone(extract_value(data['phone']))
    
    Rails.logger.info "[Pipedrive] Incoming Contact ##{data['id']}. Email: #{email}, Phone: #{phone}"
    
    return [] unless data['name'].present? || email.present? || phone.present?

    contacts = find_all_contacts(data['id'], email, phone)
    contacts << @account.contacts.new if contacts.empty?
    contacts
  end

  def sync_contact(contact, data)
    is_new = contact.new_record?

    update_contact_fields(contact, data, is_new)
    update_pipedrive_metadata(contact, data)
    save_contact_if_changed(contact)
  end

  def update_contact_fields(contact, data, is_new)
    email = extract_value(data['email'])
    phone = format_phone(extract_value(data['phone']))

    contact.name = data['name'] if sync_flags[:name] || is_new
    contact.email = email if (sync_flags[:email] || is_new) && email.present?
    contact.phone_number = phone if (sync_flags[:phone] || is_new) && phone.present?
  end

  def update_pipedrive_metadata(contact, data)
    contact.additional_attributes ||= {}
    contact.additional_attributes['pipedrive_id'] = data['id']

    sync_organization(contact, data) if sync_flags[:org]
  end

  def sync_organization(contact, data)
    company_name = resolve_company_name(data)
    contact.additional_attributes['company_name'] = company_name if company_name.present?
  end

  def resolve_company_name(data)
    org_id_val = data['org_id']
    return nil unless org_id_val.present?

    return data['org_name'] if data['org_name'].present?
    return org_id_val['name'] if org_id_val.is_a?(Hash) && org_id_val['name'].present?
    
    fetch_organization_name(org_id_val) if numeric?(org_id_val)
  end

  def numeric?(value)
    value.is_a?(Numeric) || value.to_s.match?(/^\d+$/)
  end

  def fetch_organization_name(org_id)
    return nil unless client
    
    org_res = client.organization_details(id: org_id)
    org_res.dig('data', 'name') if org_res&.dig('success')
  rescue => e
    Rails.logger.warn "[Pipedrive] Failed to fetch organization: #{e.message}"
    nil
  end

  def save_contact_if_changed(contact)
    return log_no_changes(contact) unless contact.changed? || contact.new_record?

    mark_as_pipedrive_source(contact) if contact.persisted?
    
    if contact.save
      mark_as_pipedrive_source(contact) if contact.previously_new_record?
      apply_pipedrive_label(contact)
    end
  end

  def log_no_changes(contact)
    Rails.logger.info "[Pipedrive] Skipping Contact ##{contact.id} - no changes"
  end

  def mark_as_pipedrive_source(contact)
    Rails.cache.write("pipedrive_source_#{contact.id}", true, expires_in: CACHE_EXPIRY)
  end

  def apply_pipedrive_label(contact)
    return unless contact.persisted?
    
    label = find_or_create_label
    contact.add_labels([LABEL_TITLE]) if label
  end

  def find_or_create_label
    @account.labels.find_by(title: LABEL_TITLE) || create_label
  end

  def create_label
    @account.labels.create!(
      title: LABEL_TITLE,
      color: DEFAULT_LABEL_COLOR,
      show_on_sidebar: true
    )
  rescue ActiveRecord::RecordInvalid
    @account.labels.find_by(title: LABEL_TITLE)
  end

  def find_all_contacts(pipedrive_id, email, phone)
    by_pipedrive_id(pipedrive_id) ||
    by_phone(phone) ||
    by_email(email) ||
    []
  end

  def by_pipedrive_id(pipedrive_id)
    contacts = @account.contacts.where(
      "additional_attributes->>'pipedrive_id' = ?",
      pipedrive_id.to_s
    ).to_a
    contacts.presence
  end

  def by_phone(phone)
    return nil unless phone.present?
    contacts = @account.contacts.where(phone_number: phone).to_a
    contacts.presence
  end

  def by_email(email)
    return nil unless email.present?
    contacts = @account.contacts.where(email: email.downcase).to_a
    contacts.presence
  end

  def extract_value(field)
    return nil if field.blank?

    if field.is_a?(Array)
      item = field.find { |f| f['primary'] } || field.first
      item&.dig('value')
    else
      field
    end
  end

  def format_phone(phone)
    return nil if phone.blank?

    country_code = @account.locale.to_s.split('_').last.presence || 'US'
    parsed = ::Phonelib.parse(phone, country_code)
    
    parsed.valid? ? parsed.full_e164 : nil
  end
end
