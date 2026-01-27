class Crm::Pipedrive::FetchCustomerContextService
  require 'pipedrive_client'

  def initialize(contact:)
    @contact = contact
    @account = contact.account
    @hook = @account.hooks.find_by(app_id: 'pipedrive')
    @api_token = @hook&.settings&.dig('api_token')
    @base_url = @hook&.settings&.dig('base_url').presence || "https://api.pipedrive.com"
  end

  def perform
    return { error: 'Pipedrive integration not configured for this account' } unless @hook
    return { error: 'Pipedrive API Token missing' } if @api_token.blank?

    client = PipedriveClient.new(base_url: @base_url, api_token: @api_token)
    
    # Try to find person using stored ID first
    person_id = @contact.additional_attributes['pipedrive_id']
    
    # Search if no ID...
    unless person_id
      phone = @contact.phone_number
      email = @contact.email
      
      raw_phone = phone.to_s.gsub(/\D/, '')
      phone_without_55 = raw_phone.sub(/^55/, '')
      
      term = raw_phone.presence || email.presence
      Rails.logger.info "[Pipedrive] Searching for term: #{term}"
      
      return { found: false, message: 'No phone or email to search' } if term.blank?

      # 1. First attempt: Search with FULL number
      search_result = client.search_person(term: term, exact_match: true)

      # 2. If failed and phone had 55, try WITHOUT 55
      items = search_result&.dig('data', 'items')
      if (items.blank?) && raw_phone != phone_without_55
         search_result = client.search_person(term: phone_without_55, exact_match: true)
      end
      
      # 3. Fuzzy
      items = search_result&.dig('data', 'items')
      if items.blank? && phone_without_55.present?
         search_result = client.search_person(term: phone_without_55, exact_match: false)
      end
      
      unless search_result && search_result['success']
        return { found: false, error: 'Pipedrive API Error' } 
      end

      items = search_result.dig('data', 'items') || []
      
      if items.any?
        person_item = items.first['item']
        person_id = person_item['id']
        org_id = person_item.dig('organization', 'id')
        
        # Persist mapping
        @contact.additional_attributes['pipedrive_id'] = person_id
        @contact.save!
      end
    end

    return { found: false } unless person_id

    # Fetch bundled data
    # Fetch bundled data
    person_details_response = client.person_details(
      id: person_id,
      include_fields: "open_deals_count,activities_count,notes_count,files_count"
    )

    unless person_details_response && person_details_response['success']
        return { found: false, error: 'Pipedrive API Error (Details)' } 
    end

    details = person_details_response.dig('data') || {}

    # Deals
    deals_open = client.deals(person_id: person_id, status: 'open')&.dig('data') || []
    deals_won  = client.deals(person_id: person_id, status: 'won')&.dig('data') || []
    deals_lost = client.deals(person_id: person_id, status: 'lost')&.dig('data') || []

    # Activities
    upcoming_data = client.activities(person_id: person_id, done: false, limit: 50)&.dig('data') || []
    recent_data = client.activities(person_id: person_id, limit: 50, sort_by: 'update_time', sort_direction: 'desc')&.dig('data') || []
    
    # Helper to map activity fields
    map_activity = ->(a) {
      {
        id: a['id'],
        subject: a['subject'],
        done: a['done'],
        type: a['type'],
        priority: a['priority'],
        due_date: a['due_date'],
        due_time: a['due_time'],
        duration: a['duration'],
        busy: a['busy'] || a['busy_flag'],
        deal_title: a['deal_title'], # API usually provides this flat
        person_name: a['person_name'],
        org_name: a['org_name'],
        lead_title: a['lead_title'],
        owner_name: a['owner_name'],
        owner_id: a['owner_id'] || a['user_id'],
        user_id: a['user_id'] || a['owner_id'],
        lead_id: a['lead_id'], # Ensure ID is passed
        deal_id: a['deal_id'],
        # Extra fields if available logic needed:
        note: a['note']
      }
    }

    upcoming = upcoming_data.map(&map_activity)
    recent = recent_data.map(&map_activity)
    calls = recent.select { |a| a[:type] == 'call' } # Keep for backward compatibility if used

    # Leads
    leads = client.leads(person_id: person_id)&.dig('data') || []

    # Notes
    notes = client.notes(person_id: person_id, limit: 30)&.dig('data') || []

    # Organization processing
    org_data = nil
    if details['org_id'].present?
      if details['org_id'].is_a?(Hash)
         org_data = { id: details['org_id']['value'], name: details['org_id']['name'] }
      elsif details['org_id'].is_a?(Integer) || details['org_id'].is_a?(String)
         # If just ID (integer/string), fetch details separately
         org_resp = client.organization_details(id: details['org_id'])
         if org_resp && org_resp['success']
            org_item = org_resp['data']
            org_data = { id: org_item['id'], name: org_item['name'], address: org_item['address'] }
         end
      end
    end

    response = {
      source: 'pipedrive',
      matched_by: 'id',
      pipedrive: {
        person: details,
        organization: org_data,
        leads: leads,
        deals: { open: deals_open, won: deals_won, lost: deals_lost },
        activities: { upcoming: upcoming, recent: recent, calls: calls },
        notes: notes
      },
      sync: {
        last_sync_at: Time.now.iso8601,
        cache_ttl_sec: 120
      }
    }

    response
  end

  def deals
    setup_client_and_person
    return @setup_error if @setup_error

    # Fetch Deals
    deals_open = @client.deals(person_id: @person_id, status: 'open')&.dig('data') || []
    deals_won  = @client.deals(person_id: @person_id, status: 'won')&.dig('data') || []
    deals_lost = @client.deals(person_id: @person_id, status: 'lost')&.dig('data') || []

    # Fetch Metadata for Enrichment
    stages_res = @client.stages
    stages_map = {}
    if stages_res && stages_res['success']
      stages_res['data'].each { |s| stages_map[s['id']] = s['name'] }
    end

    fields_res = @client.deal_fields
    labels_map = {}
    if fields_res && fields_res['success']
      label_field = fields_res['data'].find { |f| f['key'] == 'label' || f['name'].to_s.downcase == 'label' }
      if label_field && label_field['options']
        label_field['options'].each { |opt| labels_map[opt['id']] = opt['label'] }
      end
    end

    all_deals = [deals_open, deals_won, deals_lost]
    
    # Sort by stage_id ascending (smallest to largest)
    all_deals.each do |list|
      list.sort_by! { |d| d['stage_id'].to_i }
    end

    # Enrich
    all_deals.each do |list|
      list.each do |d|
        # URL
        d['url'] = generate_url('deal', d['id'])

        # Formatted Value
        if d['value']
          currency = d['currency'] || 'BRL'
          # Use Brazilian formatting for BRL, otherwise standard
          if currency == 'BRL'
             d['formatted_value'] = ActionController::Base.helpers.number_to_currency(d['value'], unit: "R$ ", separator: ",", delimiter: ".")
          else
             d['formatted_value'] = "#{currency} #{d['value']}"
          end
        end

        # Stage Name
        if d['stage_id'] && stages_map[d['stage_id']]
          d['stage_id'] = stages_map[d['stage_id']]
        end

        # Labels
        # API v1: 'label' (id), API v2/New: 'label_ids' (array)
        l_ids = d['label_ids'] || (d['label'] ? [d['label']] : [])
        if l_ids.present? && l_ids.is_a?(Array)
          names = l_ids.map { |lid| labels_map[lid] }.compact
          d['label'] = names.join(', ') if names.any?
        end
      end
    end

    { deals: { open: deals_open, won: deals_won, lost: deals_lost } }
  end

  def leads
    setup_client_and_person
    return @setup_error if @setup_error

    raw_leads = @client.leads(person_id: @person_id)
    Rails.logger.info "[Pipedrive] Leads Response for Person #{@person_id}: #{raw_leads.inspect}"
    leads = raw_leads&.dig('data') || []

    # Fetch Labels
    labels_res = @client.lead_labels
    labels_map = {}
    if labels_res && labels_res['success']
      labels_res['data'].each { |l| labels_map[l['id']] = l['name'] }
    end

    leads.each do |l|
      l['url'] = generate_url('lead', l['id'])

      # Format Date
      if l['add_time'].present?
        begin
          l['formatted_date'] = Date.parse(l['add_time']).strftime('%d/%m/%Y')
        rescue => e
          Rails.logger.warn("Date parse error for Pipedrive lead: #{e.message}")
        end
      end

      # Resolve Labels
      l_ids = l['label_ids']
      if l_ids.present? && l_ids.is_a?(Array)
        names = l_ids.map { |lid| labels_map[lid] }.compact
        l['label'] = names.join(', ') if names.any?
      end
    end

    { leads: leads }
  end

  def activities
    setup_client_and_person
    return @setup_error if @setup_error

    upcoming = @client.activities(person_id: @person_id, done: false, limit: 20, sort_by: 'due_date', sort_direction: 'asc')&.dig('data') || []
    
    # Sort in memory to handle time properly (API might just sort by date)
    upcoming.sort_by! do |a|
       date = a['due_date'].presence || '9999-12-31'
       time = a['due_time'].presence || '23:59'
       "#{date} #{time}"
    end

    recent = @client.activities(person_id: @person_id, limit: 5, sort_by: 'update_time', sort_direction: 'desc')&.dig('data') || []
    
    # Pre-fetch users for mapping names if missing
    users_res = @client.users
    users_map = {}
    if users_res && users_res['success']
      users_res['data'].each { |u| users_map[u['id']] = u['name'] }
    end

    # Inject URLs, Format Dates and Enrich Names
    [upcoming, recent].each do |list|
      list.each do |a| 
        a['url'] = generate_url('activity', a['id'])
        
        # Inject Deal URL & Title
        if a['deal_id']
          a['deal_url'] = generate_url('deal', a['deal_id'])
        end
        
        # Inject Owner Name if missing (for frontend dropdown pre-fill)
        target_oid = a['owner_id'] || a['user_id']
        a['owner_id'] = target_oid
        a['user_id'] = target_oid # Normalize for frontend
        if target_oid && !a['owner_name']
           a['owner_name'] = users_map[target_oid]
        end
        
        # Normalize busy flag
        a['busy'] = a['busy'] || a['busy_flag']

        # Inject Lead Title fallback? (Hard to do efficiently)
        # Assuming Pipedrive provides lead_title or similar in v1.
        # If not, frontend will show ID.

        # Format Date to Brazilian standard
        if a['due_date'].present?
           begin
             date_obj = Date.parse(a['due_date'])
             formatted = date_obj.strftime('%d/%m/%Y')
             
             if a['due_time'].present?
                # Ensure HH:MM format
                hm = a['due_time'].to_s.split(':')[0..1].join(':')
                formatted = "#{formatted} #{hm}"
             end

             a['due_date'] = formatted
           rescue => e
             Rails.logger.warn("Date parse error for Pipedrive activity: #{e.message}")
           end
        end
      end
    end

    { activities: { upcoming: upcoming, recent: recent } }
  end

  def generate_url(type, id)
    domain = @hook&.settings&.dig('company_domain')
    return nil unless domain.present?

    base = "https://#{domain}.pipedrive.com"
    case type
    when 'deal'
      "#{base}/deal/#{id}"
    when 'lead'
      "#{base}/leads/inbox/#{id}"
    when 'activity'
      "#{base}/activities/list/user/everyone?selected=#{id}&tab=activity"
    end
  end

  private

  def setup_client_and_person
    return @setup_error = { error: 'Pipedrive integration not configured' } unless @hook
    return @setup_error = { error: 'Pipedrive API Token missing' } if @api_token.blank?

    @client = PipedriveClient.new(base_url: @base_url, api_token: @api_token)
    
    # Ensure ID
    @person_id = @contact.additional_attributes['pipedrive_id']
    
    # If no ID, run logic to find it (using perform's logic equivalent if reused, or simplified)
    unless @person_id
       find_result = find_person_id
       if find_result[:found]
          @person_id = find_result[:id]
       else
          @setup_error = { error: 'Person not found in Pipedrive' }
       end
    end
  end

  def find_person_id
      phone = @contact.phone_number
      email = @contact.email
      # ... logic same as perform ...
      # Simplified for this context:
      
      raw_phone = phone.to_s.gsub(/\D/, '')
      phone_without_55 = raw_phone.sub(/^55/, '')
      term = raw_phone.presence || email.presence
      
      return { found: false } if term.blank?

      res = @client.search_person(term: term, exact_match: true)
      
      if (!res || !res['success'] || res.dig('data', 'items').blank?) && raw_phone != phone_without_55
         res = @client.search_person(term: phone_without_55, exact_match: true)
      end
      
      if (!res || !res['success'] || res.dig('data', 'items').blank?) && phone_without_55.present?
         res = @client.search_person(term: phone_without_55, exact_match: false)
      end

      items = res&.dig('data', 'items') || []
      if items.any?
        pid = items.first['item']['id']
        # Save it
        @contact.additional_attributes['pipedrive_id'] = pid
        @contact.save!
        return { found: true, id: pid }
      end

      { found: false }
  end
end
