class Crm::Pipedrive::IncomingContactService
  def initialize(account:)
    @account = account
    @hook = @account.hooks.find_by(app_id: 'pipedrive')
  end

  def create_or_update(data)
    # Avoid echo: if we just synced this, ignored? 
    # Hard to detect without timestamp comparison or unique request ID.
    # We will just process. Idempotency is key.

    # Init Client for labels
    client = nil
    if @hook && @hook.settings && @hook.settings['api_token']
       client = PipedriveClient.new(base_url: @hook.settings['pipedrive_url'], api_token: @hook.settings['api_token'])
    end

    # Check Settings
    settings = @hook.settings || {}
    return unless settings['sync_contacts']

    pipedrive_id = data['id']
    return if Rails.cache.read("chatwoot_source_#{pipedrive_id}")

    do_sync_phone = settings['sync_phone'] != false
    do_sync_email = settings['sync_email'] != false
    do_sync_name  = settings['sync_name'] != false
    do_sync_org   = settings['sync_organization'] != false

    pipedrive_id = data['id']
    person_name = data['name']
    
    # Extract Email/Phone
    email = extract_value(data['email'])
    phone = extract_value(data['phone'])
    
    Rails.logger.info "[Pipedrive] Incoming Contact ##{data['id']}. Extracted Email: #{email}, Phone: #{phone}"

    return unless person_name.present? || email.present? || phone.present?

    formatted_phone = format_phone(phone)

    # Find ALL Contacts linked to this Pipedrive ID to resolve duplicates/split-brain
    contacts = find_all_contacts(pipedrive_id, email, formatted_phone)
    contacts << @account.contacts.new(account: @account) if contacts.empty?

    contacts.each do |contact|
      # Update attributes
      is_new = contact.new_record?
      
      if do_sync_name || is_new
         contact.name = person_name 
      end
      
      if (do_sync_email || is_new) && email.present?
         contact.email = email 
      end

      if (do_sync_phone || is_new) && formatted_phone.present?
         contact.phone_number = formatted_phone 
      end
      
      # Pipedrive ID
      contact.additional_attributes ||= {}
      contact.additional_attributes['pipedrive_id'] = pipedrive_id

      # Organization
      if do_sync_org
         # Organization Logic
         org_id_val = data['org_id']
         if org_id_val.present?
           company_name = nil
           
           if data['org_name'].present?
             company_name = data['org_name']
           elsif org_id_val.is_a?(Hash) && org_id_val['name'].present?
              company_name = org_id_val['name']
           elsif (org_id_val.is_a?(Numeric) || org_id_val.to_s.match?(/^\d+$/)) && client
              # Fetch from API
              begin
                org_res = client.organization_details(id: org_id_val)
                if org_res && org_res['success'] && org_res['data']
                  company_name = org_res['data']['name']
                end
              rescue => e
                Rails.logger.warn "Failed to fetch Pipedrive Org: #{e.message}"
              end
           end
     
           contact.additional_attributes['company_name'] = company_name if company_name.present?
         end
      end

      # Prevent Echo: Mark this contact as recently updated by Pipedrive
      # We set this before save for existing contacts to ensure the PushJob sees it immediately.
      
      # Only save if there are changes
      if contact.changed? || contact.new_record?
        Rails.cache.write("pipedrive_source_#{contact.id}", true, expires_in: 1.minute) if contact.persisted?

        if contact.save
          # For new records, we must set it after save (once ID exists)
          Rails.cache.write("pipedrive_source_#{contact.id}", true, expires_in: 1.minute) if contact.previously_new_record?

          apply_pipedrive_source_label(contact)
        end
      else
        Rails.logger.info "[Pipedrive] Skipping save for Contact ##{contact.id} - No changes detected."
      end
    end
  end

  private

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

  def find_all_contacts(pipedrive_id, email, phone)
    # 1. By Pipedrive ID (Find ALL matching)
    contacts = @account.contacts.where("additional_attributes->>'pipedrive_id' = ?", pipedrive_id.to_s).to_a
    return contacts if contacts.present?

    # 2. By Phone (If ID not found, try to link by phone)
    if phone.present?
      contacts = @account.contacts.where(phone_number: phone).to_a
      return contacts if contacts.present?
    end

    # 3. By Email (If ID/Phone not found, try to link by email)
    if email.present?
      contacts = @account.contacts.where(email: email.downcase).to_a
      return contacts if contacts.present?
    end
    
    []
  end

  def extract_value(field)
    return nil if field.blank?

    if field.is_a?(Array)
       item = field.find { |f| f['primary'] } || field.first
       item ? item['value'] : nil
    else
       field
    end
  end

  def format_phone(phone)
    return nil if phone.blank?

    country_code = @account.locale.to_s.split('_').last.presence || 'US'
    p = ::Phonelib.parse(phone, country_code)
    
    return p.full_e164 if p.valid?
    
    nil
  end
end
