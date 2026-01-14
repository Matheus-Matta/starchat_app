class Crm::Pipedrive::SyncContactsService
  def initialize(account:, start: 0, limit: 50)
    @account = account
    @start = start
    @limit = limit
    @hook = @account.hooks.find_by(app_id: 'pipedrive')
  end

  def perform
    Rails.logger.info "\n[Pipedrive Sync] Starting Sync with Account ID: #{@account.id}"
    return { has_more: false } unless @hook&.settings.try(:[], 'sync_contacts')
    return { has_more: false } if @hook&.settings.try(:[], 'import_contacts') == false

    url = @hook.settings['pipedrive_url']
    token = @hook.settings['api_token']
    sync_contacts = @hook.settings['sync_contacts']
    import_contacts = @hook.settings['import_contacts']

    Rails.logger.info "[Pipedrive Sync] Config: URL=#{url}, Token=#{token ? '***' : 'N/A'}, SyncContacts=#{sync_contacts}, ImportContacts=#{import_contacts}"

    client = PipedriveClient.new(base_url: url, api_token: token)

    # labels_map = fetch_labels_map(client)

    response = client.persons(start: @start, limit: @limit)
    return { has_more: false } unless response && response['success'] && response['data']

    response['data'].each do |person_data|
      sync_contact(person_data)
    rescue => e
      Rails.logger.warn "Failed to sync Pipedrive contact #{person_data['id']}: #{e.message}"
    end

    pagination = response.dig('additional_data', 'pagination')
    {
      has_more: pagination && pagination['more_items_in_collection'],
      next_start: pagination ? pagination['next_start'] : 0
    }
  rescue => e
    Rails.logger.error "Pipedrive Sync Error: #{e.message}"
    { has_more: false }
  end

  private

  def sync_contact(data)
    return unless data['name'].present?

    settings = @hook.settings || {}
    do_sync_phone = settings['sync_phone'] != false
    do_sync_email = settings['sync_email'] != false
    do_sync_name  = settings['sync_name'] != false
    do_sync_org   = settings['sync_organization'] != false

    email = extract_value(data['email'])
    phone = extract_value(data['phone'])
    
    return if email.blank? && phone.blank?

    formatted_phone = format_phone(phone)
    
    return if email.blank? && formatted_phone.blank?

    contact = find_or_initialize_contact(email, formatted_phone)
    is_new = contact.new_record?

    # Apply flags. For new records, we might want to ensure at least Name is set if available.
    if is_new || do_sync_name
       contact.name = data['name'] if data['name'].present?
    end

    if (is_new || do_sync_email) && email.present?
       contact.email = email
    end

    if (is_new || do_sync_phone) && formatted_phone.present?
       contact.phone_number = formatted_phone
    end
    
    # Always sync ID
    contact.additional_attributes ||= {}
    contact.additional_attributes['pipedrive_id'] = data['id']

    # Organization
    if do_sync_org
       if data['org_id'].present?
         org_name = data['org_id'].is_a?(Hash) ? data['org_id']['name'] : nil
         if org_name
           contact.additional_attributes['company_name'] = org_name
         end
       end
    end

    contact.save
    
    apply_pipedrive_source_label(contact) if contact.persisted?
  end

  def apply_pipedrive_source_label(contact)
    return unless contact.persisted?
    
    label_title = 'pipedrive'
    label = @account.labels.find_by(title: label_title)
    
    unless label
      begin
        label = @account.labels.create!(title: label_title, color: '#26292c', show_on_sidebar: true)
      rescue ActiveRecord::RecordInvalid
        label = @account.labels.find_by(title: label_title)
      end
    end
    
    contact.add_labels([label_title])
  end

  def extract_value(field)
    if field.is_a?(Array) && field.any?
      primary = field.find { |f| f['primary'] } || field.first
      primary['value']
    else
      field
    end
  end

  def find_or_initialize_contact(email, phone)
    contact = nil

    # Priority 1: Phone
    if phone.present?
      contact = @account.contacts.find_by(phone_number: phone)
    end

    # Priority 2: Email (only if not found by phone)
    if contact.nil? && email.present?
      contact = @account.contacts.find_by(email: email.downcase)
    end

    contact || @account.contacts.new(account: @account)
  end

  def format_phone(phone)
    return nil if phone.blank?

    # Infer country from account locale, defaulting to US (or BR if preferred by user context, sticking to locale)
    country_code = @account.locale.to_s.split('_').last.presence || 'US'
    
    # Phonelib handles the parsing. If phone starts with +, it treats as international.
    # If not, it uses country_code.
    p = ::Phonelib.parse(phone, country_code)
    
    return p.full_e164 if p.valid?
    
    nil
  end
end
