class Crm::Pipedrive::PushContactService
  def initialize(contact:)
    @contact = contact
    @account = contact.account
    @hook = @account.hooks.find_by(app_id: 'pipedrive')
  end

  def perform
    return unless @hook
    return unless @hook.settings && @hook.settings['sync_contacts']

    @client = PipedriveClient.new(base_url: @hook.settings['pipedrive_url'], api_token: @hook.settings['api_token'])

    pipedrive_id = @contact.additional_attributes['pipedrive_id']
    
    # Check if exists by searching if we don't have ID
    unless pipedrive_id
       found = find_person_in_pipedrive
       pipedrive_id = found['id'] if found
    end

    if pipedrive_id
      update_person(pipedrive_id)
    else
      create_person
    end
  end

  private

  def find_person_in_pipedrive
    # Search by Phone first
    if @contact.phone_number.present?
      res = @client.search_person(term: @contact.phone_number)
      if res && res['success'] && res['data'].present? && res['data']['items'].present?
        return res['data']['items'].first['item']
      end
    end

    # Search by Email
    if @contact.email.present?
      res = @client.search_person(term: @contact.email)
      if res && res['success'] && res['data'].present? && res['data']['items'].present?
        return res['data']['items'].first['item']
      end
    end
    nil
  end

  def create_person
    # Check settings
    settings = @hook.settings || {}
    do_sync_phone = settings['sync_phone'] != false
    do_sync_email = settings['sync_email'] != false
    do_sync_org   = settings['sync_organization'] != false
    
    # Name is required for creation
    payload = {
      name: @contact.name || @contact.phone_number || @contact.email, 
      email: (do_sync_email ? @contact.email : nil),
      phone: (do_sync_phone ? @contact.phone_number : nil)
    }
    
    # Organization
    if do_sync_org
      org_id = resolve_org_id
      payload[:org_id] = org_id if org_id
    end

    res = @client.create_person(payload)
    if res && res['success']
      pipedrive_id = res['data']['id']
      set_source_cache(pipedrive_id)
      update_contact_attributes(pipedrive_id)
    end
  end

  def update_person(id)
    # Check remote state first to avoid redundant updates and loops
    remote_person = @client.person_details(id: id)
    return unless remote_person && remote_person['success'] && remote_person['data']
    
    remote_data = remote_person['data']

    settings = @hook.settings || {}
    do_sync_phone = settings['sync_phone'] != false
    do_sync_email = settings['sync_email'] != false
    do_sync_name  = settings['sync_name'] != false
    do_sync_org   = settings['sync_organization'] != false

    payload = {}
    
    # Name
    if do_sync_name && @contact.name.present? && @contact.name != remote_data['name']
      payload[:name] = @contact.name
    end

    # Email (Remote is array of objects)
    if do_sync_email && @contact.email.present?
      remote_emails = (remote_data['email'] || []).map { |e| e['value'] }
      unless remote_emails.include?(@contact.email)
        payload[:email] = @contact.email
      end
    end

    # Phone (Remote is array of objects)
    if do_sync_phone && @contact.phone_number.present?
      remote_phones = (remote_data['phone'] || []).map { |p| p['value'] }
      # Could improve with normalization using Phonelib if needed, but strict check is safer for now.
      unless remote_phones.include?(@contact.phone_number)
        payload[:phone] = @contact.phone_number
      end
    end
    
    # Organization
    if do_sync_org
       org_id = resolve_org_id
       # Only update if different
       if org_id && remote_data['org_id'] != org_id
         payload[:org_id] = org_id
       end
    end

    if payload.empty?
      Rails.logger.info "[Pipedrive] Skipping Push for Contact ##{@contact.id} - No changes detected vs Pipedrive."
      return
    end

    Rails.logger.info "[Pipedrive] Pushing update for Contact ##{@contact.id} (Pipedrive ID: #{id}). Payload: #{payload.inspect}"
    res = @client.update_person(id: id, payload: payload)
    set_source_cache(id) if res && res['success']
  end

  def set_source_cache(pipedrive_id)
    Rails.cache.write("chatwoot_source_#{pipedrive_id}", true, expires_in: 1.minute)
  end

  def update_contact_attributes(pipedrive_id)
    @contact.additional_attributes['pipedrive_id'] = pipedrive_id
    @contact.save
  end

  def resolve_org_id
    company_name = @contact.additional_attributes['company_name']
    return nil unless company_name.present?

    # Normalize the company name (trim, single spaces, case-insensitive comparison)
    normalized_name = company_name.strip.squeeze(' ')
    
    Rails.logger.info "[Pipedrive] Resolving organization for '#{company_name}' (normalized: '#{normalized_name}')"

    # Search for existing organization
    res = @client.search_organization(term: normalized_name)
    if res && res['success'] && res['data']['items'].present?
      # Try exact match first (case-insensitive, normalized)
      exact_match = res['data']['items'].find do |i|
        org_name = i['item']['name'].to_s.strip.squeeze(' ')
        org_name.casecmp?(normalized_name)
      end
      
      if exact_match
        org_id = exact_match['item']['id']
        org_current_name = exact_match['item']['name']
        
        Rails.logger.info "[Pipedrive] Found exact match: Org ID=#{org_id}, Name='#{org_current_name}'"
        
        # Update organization name if it changed (to keep it in sync)
        if org_current_name != company_name
          Rails.logger.info "[Pipedrive] Updating org name from '#{org_current_name}' to '#{company_name}'"
          update_res = @client.update_organization(id: org_id, payload: { name: company_name })
          Rails.logger.warn "[Pipedrive] Failed to update org name" unless update_res && update_res['success']
        end
        
        return org_id
      end
      
      # Try partial match (first result from search) as fallback
      first_result = res['data']['items'].first
      first_org_name = first_result['item']['name'].to_s.strip.squeeze(' ')
      
      # Only use if very similar (same normalized version or contains)
      if first_org_name.casecmp?(normalized_name) || 
         first_org_name.downcase.include?(normalized_name.downcase) ||
         normalized_name.downcase.include?(first_org_name.downcase)
        
        org_id = first_result['item']['id']
        Rails.logger.info "[Pipedrive] Using similar match: Org ID=#{org_id}, Name='#{first_org_name}'"
        
        # Update to exact name
        if first_org_name != company_name
          Rails.logger.info "[Pipedrive] Updating similar org name to '#{company_name}'"
          @client.update_organization(id: org_id, payload: { name: company_name })
        end
        
        return org_id
      end
    end
    
    # Create new organization only if no match found
    Rails.logger.info "[Pipedrive] No match found, creating new organization '#{company_name}'"
    res = @client.create_organization(name: company_name)
    if res && res['success']
      org_id = res['data']['id']
      Rails.logger.info "[Pipedrive] Created new organization: ID=#{org_id}"
      return org_id
    end
    
    nil
  rescue => e
    Rails.logger.warn "[Pipedrive] Failed to resolve Org: #{e.class} - #{e.message}"
    nil
  end
end
