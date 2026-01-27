# frozen_string_literal: true
require "json"
require "faraday"

class PipedriveClient
  ENDPOINTS = {
    persons_search: "/api/v2/persons/search",
    persons:        "/api/v2/persons",
    person_details: "/api/v2/persons/%{id}",
    person_fields:  "/api/v2/personFields",
    deals:          "/api/v2/deals",
    deal_details:   "/api/v2/deals/%{id}",
    activities:     "/api/v2/activities",
    deals_search:   "/api/v2/deals/search",
    leads_search:   "/v1/leads/search", # Leads search often V1/search or itemSearch, using V1 prefix
    leads:          "/v1/leads",
    notes:          "/api/v2/notes",
    organization:   "/api/v2/organizations/%{id}",
    stages:         "/api/v2/stages",
    deal_fields:    "/api/v2/dealFields",
    lead_labels:    "/api/v2/leadLabels",
    webhooks:       "/api/v2/webhooks",
    organizations_search: "/api/v2/organizations/search",
    organizations:        "/api/v2/organizations",
    products_search:      "/api/v2/products/search",
    products:             "/api/v2/products",
    filters:              "/api/v2/filters",
    users:                "/v1/users"
  }.freeze

  def initialize(base_url:, api_token:)
    base_url = base_url.chomp('/')
    @conn = Faraday.new(url: base_url) do |f|
      f.request :json
      f.response :raise_error
      f.adapter Faraday.default_adapter
    end
    @api_token = api_token&.strip
  end

  def filters(type:)
    get(ENDPOINTS[:filters], params: { type: type })
  end

  def get(path, params: {})
    params = params.compact
    
    resp = @conn.get(path) do |req|
      req.params['api_token'] = @api_token
      req.params.update(params)
    end
    
    # Log full sanitized URL for debugging auth issues
    full_uri = resp.env.url.to_s
    log_uri = full_uri.gsub(@api_token, "#{@api_token[0..4]}***#{@api_token[-3..]}") if @api_token.present?
    
    Rails.logger.info "🔍 Pipedrive GET Request: #{log_uri || full_uri}"
    
    result = JSON.parse(resp.body)
    data_count = if result['data'].is_a?(Array)
                   result['data'].size
                 elsif result['data'].is_a?(Hash)
                   1
                 else
                   'N/A'
                 end
    
    Rails.logger.info "🔍 Pipedrive Response success: #{result['success']}, data count: #{data_count}"
    result
  rescue Faraday::Error => e
    Rails.logger.error("Pipedrive API Error: #{e.message}")
    if e.response
      puts "🔴 [Pipedrive] Error Status: #{e.response[:status]}"
      puts "🔴 [Pipedrive] Error Body: #{e.response[:body]}"
      Rails.logger.error("Pipedrive Error Status: #{e.response[:status]}")
      Rails.logger.error("Pipedrive Error Body: #{e.response[:body]}")
      
      # Handle unauthorized/subscription expired errors
      if [401, 403].include?(e.response[:status])
        return { 
          'success' => false, 
          'error' => 'Acesso não autorizado ou assinatura expirada no Pipedrive.',
          'errorCode' => e.response[:status]
        }
      end
    end
    nil
  end

  def search_person(term:, fields: "phone,email", exact_match: true, limit: 10)
    get(ENDPOINTS[:persons_search], params: { term: term, fields: fields, exact_match: exact_match, limit: limit })
  end

  def person_details(id:, include_fields: nil, custom_fields: nil)
    path = ENDPOINTS[:person_details] % { id: id }
    params = {}
    params[:include_fields] = include_fields if include_fields
    params[:custom_fields] = custom_fields if custom_fields
    get(path, params: params)
  end

  def deals(person_id: nil, filter_id: nil, user_id: nil, owner_id: nil, stage_id: nil, org_id: nil, status: "open", start: 0, limit: 100, sort: nil, user_name: nil, stage_name: nil, person_name: nil, org_name: nil, get_summary: nil)
    params = { limit: limit, get_summary: get_summary }
    params[:start] = start if start&.positive?
    params[:status] = status unless ['all_not_deleted', 'open'].include?(status)
    
    owner_id  ||= find_user_id_by_name(user_name) if user_name.present?
    stage_id  ||= find_stage_id_by_name(stage_name) if stage_name.present?
    person_id ||= find_person_id_by_name(person_name) if person_name.present?
    org_id    ||= find_org_id_by_name(org_name) if org_name.present?

    final_owner_id = owner_id || user_id

    params[:person_id] = person_id if person_id
    params[:filter_id] = filter_id if filter_id
    params[:owner_id]  = final_owner_id if final_owner_id
    params[:stage_id]  = stage_id if stage_id
    params[:org_id]    = org_id if org_id
    
    if sort
      parts = sort.split(' ')
      params[:sort_by] = parts[0] if parts[0]
      params[:sort_direction] = parts[1] if parts[1]
    end
    
    get(ENDPOINTS[:deals], params: params)
  end

  def activities(filter_id: nil, ids: nil, owner_id: nil, deal_id: nil, lead_id: nil, person_id: nil, org_id: nil, done: nil, updated_since: nil, updated_until: nil, start_date: nil, end_date: nil, sort_by: "due_date", sort_direction: "asc", include_fields: nil, limit: 100, start: 0, cursor: nil, user_name: nil, person_name: nil, org_name: nil, get_summary: nil, type: nil)
    params = { limit: limit, sort_by: sort_by, sort_direction: sort_direction, get_summary: get_summary }
    params[:start] = start if start&.positive? && cursor.nil?

    owner_id  ||= find_user_id_by_name(user_name) if user_name.present?
    person_id ||= find_person_id_by_name(person_name) if person_name.present?
    org_id    ||= find_org_id_by_name(org_name) if org_name.present?

    Rails.logger.info "[PipedriveClient] Activities filter - Name: #{user_name}, Resolved Owner ID: #{owner_id}" if user_name.present?
    
    params[:owner_id]       = owner_id if owner_id
    params[:filter_id]      = filter_id if filter_id
    params[:ids]            = ids if ids
    params[:deal_id]        = deal_id if deal_id
    params[:lead_id]        = lead_id if lead_id
    params[:person_id]      = person_id if person_id
    params[:org_id]         = org_id if org_id
    params[:done]           = done if done
    params[:type]           = type if type
    params[:startDate]      = start_date if start_date
    params[:endDate]        = end_date if end_date
    params[:updated_since]  = updated_since if updated_since
    params[:updated_until]  = updated_until if updated_until
    params[:include_fields] = include_fields if include_fields
    params[:cursor]         = cursor if cursor

    get(ENDPOINTS[:activities], params: params)
  end

  def activities_search(term:, start: 0, limit: 50)
    person_id = find_person_id_by_name(term)
    return activities(person_id: person_id, start: start, limit: limit) if person_id

    org_id = find_org_id_by_name(term)
    return activities(org_id: org_id, start: start, limit: limit) if org_id

    empty_response(start, limit)
  end

  def leads_search(term:, person_id: nil, start: 0, limit: 50)
    params = { term: term, start: start, limit: limit }
    params[:person_id] = person_id if person_id
    get(ENDPOINTS[:leads_search], params: params)
  end

  def deals_search(term:, start: 0, limit: 50)
    get(ENDPOINTS[:deals_search], params: { term: term, start: start, limit: limit })
  end

  def leads(person_id: nil, org_id: nil, organization_id: nil, title: nil, owner_id: nil, archived_status: nil, start: 0, limit: 50, sort: nil, user_name: nil, person_name: nil, org_name: nil, get_summary: nil)
    params = { start: start, limit: limit, get_summary: get_summary }

    owner_id  ||= find_user_id_by_name(user_name) if user_name.present?
    person_id ||= find_person_id_by_name(person_name) if person_name.present?
    org_id    ||= find_org_id_by_name(org_name) if org_name.present?

    final_org_id = organization_id || org_id

    params[:person_id]       = person_id if person_id
    params[:organization_id] = final_org_id if final_org_id
    params[:title]           = title if title
    params[:owner_id]        = owner_id if owner_id
    params[:archived_status] = archived_status if archived_status
    params[:sort]            = sort if sort

    get(ENDPOINTS[:leads], params: params)
  end

  def notes(person_id:, limit: 50)
    get(ENDPOINTS[:notes], params: { person_id: person_id, limit: limit, sort: "update_time DESC" })
  end

  def organization_details(id:)
    get(ENDPOINTS[:organization] % { id: id })
  end

  def stages
    get(ENDPOINTS[:stages])
  end

  def deal_fields
    get(ENDPOINTS[:deal_fields])
  end

  def lead_labels
    get(ENDPOINTS[:lead_labels])
  end

  def persons(start: 0, limit: 50)
    get(ENDPOINTS[:persons], params: { start: start, limit: limit })
  end

  def person_fields
    get(ENDPOINTS[:person_fields])
  end

  def create_person(name:, email: nil, phone: nil, org_id: nil, owner_id: nil)
    payload = { name: name }
    payload[:email]    = email if email
    payload[:phone]    = phone if phone
    payload[:org_id]   = org_id if org_id
    payload[:owner_id] = owner_id if owner_id

    post(ENDPOINTS[:persons], payload: payload)
  end

  def update_person(id:, payload:)
    return unless id
    put(ENDPOINTS[:person_details] % { id: id }, payload: payload)
  end

  def delete_person(id:)
    delete(ENDPOINTS[:person_details] % { id: id })
  end

  def webhooks
    get(ENDPOINTS[:webhooks])
  end

  def create_webhook(subscription_url:, event_action: "*", event_object: "*")
    post(ENDPOINTS[:webhooks], payload: {
      subscription_url: subscription_url,
      event_action: event_action,
      event_object: event_object,
      user_id: nil
    })
  end

  def delete_webhook(id:)
    delete("#{ENDPOINTS[:webhooks]}/#{id}")
  end
  def products(limit: 50, start: 0)
    get(ENDPOINTS[:products], params: { limit: limit, start: start })
  end

  def search_products(term:, limit: 5)
    get(ENDPOINTS[:products_search], params: { term: term, limit: limit })
  end

  def search_organization(term:, limit: 10)
    get(ENDPOINTS[:organizations_search], params: { term: term, limit: limit })
  end

  def create_organization(payload)
    post(ENDPOINTS[:organizations], payload: payload)
  end

  def update_organization(id:, payload:)
    put("#{ENDPOINTS[:organizations]}/#{id}", payload: payload)
  end

  def create_deal(payload)
    post(ENDPOINTS[:deals], payload: payload)
  end

  def create_activity(payload)
    post(ENDPOINTS[:activities], payload: payload)
  end

  def create_lead(payload)
    post("/v1/leads", payload: payload)
  end

  def update_deal(id:, payload:)
    put("/api/v2/deals/#{id}", payload: payload)
  end

  def delete_deal(id:)
    delete("/api/v2/deals/#{id}")
  end

  def update_lead(id:, payload:)
    patch("/v1/leads/#{id}", payload: payload)
  end

  def delete_lead(id:)
    delete("/v1/leads/#{id}")
  end

  def update_activity(id:, payload:)
    patch("/api/v2/activities/#{id}", payload: payload)
  end

  def delete_activity(id:)
    delete("/api/v2/activities/#{id}")
  end

  # Deal-specific operations (require deal_id)
  def add_deal_follower(deal_id:, user_id:)
    post("/api/v2/deals/#{deal_id}/followers", payload: { user_id: user_id })
  end

  def add_deal_participant(deal_id:, person_id:)
    post("/v1/deals/#{deal_id}/participants", payload: { person_id: person_id })
  end

  def add_deal_product(deal_id:, payload:)
    post("/api/v2/deals/#{deal_id}/products", payload: payload)
  end

  def add_deal_products_bulk(deal_id:, items:)
    post("/api/v2/deals/#{deal_id}/products/bulk", payload: { data: items })
  end

  def add_deal_discount(deal_id:, description:, amount:, type:)
    post("/api/v2/deals/#{deal_id}/discounts", payload: {
      description: description,
      amount: amount,
      type: type
    })
  end

  def add_deal_installment(deal_id:, description:, amount:, billing_date:)
    post("/api/v2/deals/#{deal_id}/installments", payload: {
      description: description,
      amount: amount,
      billing_date: billing_date
    })
  end

  def convert_deal_to_lead(deal_id:)
    post("/api/v2/deals/#{deal_id}/convert/lead", payload: {})
  end

  def delete(path)
    resp = @conn.delete(path) { |req| req.params['api_token'] = @api_token }
    JSON.parse(resp.body)
  rescue Faraday::Error => e
    Rails.logger.error("Pipedrive DELETE Error: #{e.message}")
    nil
  end

  def post(path, payload:)
    resp = @conn.post(path) do |req|
      req.params['api_token'] = @api_token
      req.body = payload.to_json
    end
    JSON.parse(resp.body)
  rescue Faraday::Error => e
    Rails.logger.error("Pipedrive POST Error: #{e.message}")
    Rails.logger.error("Pipedrive Error Response: #{e.response[:body]}") if e.response
    nil
  end

  def put(path, payload:)
    resp = @conn.put(path) do |req|
      req.params['api_token'] = @api_token
      req.body = payload.to_json
    end
    JSON.parse(resp.body)
  rescue Faraday::Error => e
    Rails.logger.error("Pipedrive API Error: #{e.message}")
    nil
  end

  def patch(path, payload:)
    resp = @conn.patch(path) do |req|
      req.params['api_token'] = @api_token
      req.body = payload
    end
    JSON.parse(resp.body)
  rescue Faraday::Error => e
    puts "🔴 [Pipedrive PATCH] Error Status: #{e.response[:status]}" if e.response
    puts "🔴 [Pipedrive PATCH] Error Body: #{e.response[:body]}" if e.response
    Rails.logger.error("Pipedrive API Error: #{e.message}")
    nil
  end

  private

  def empty_response(start, limit)
    {
      'success' => true,
      'data' => [],
      'additional_data' => {
        'pagination' => { 'start' => start, 'limit' => limit, 'more_items_in_collection' => false },
        'summary' => { 'total_count' => 0 }
      }
    }
  end

  def find_person_id_by_name(name)
    response = get(ENDPOINTS[:persons_search], params: { term: name, limit: 1 })
    return nil unless valid_search_response?(response)
    
    response.dig('data', 'items')&.first&.dig('item', 'id')
  rescue => e
    Rails.logger.error("Pipedrive find_person_id_by_name error: #{e.message}")
    nil
  end

  def find_org_id_by_name(name)
    response = get(ENDPOINTS[:organizations_search], params: { term: name, limit: 1 })
    return nil unless valid_search_response?(response)
    
    response.dig('data', 'items')&.first&.dig('item', 'id')
  rescue => e
    Rails.logger.error("Pipedrive find_org_id_by_name error: #{e.message}")
    nil
  end

  def find_user_id_by_name(name)
    response = get(ENDPOINTS[:users])
    return nil unless response&.dig('success') && response['data'].present?
    
    Rails.logger.info "[PipedriveClient] Searching for user: #{name}"
    user = response['data'].find { |u| u['name'].casecmp(name).zero? || u['email'].casecmp(name).zero? }
    Rails.logger.info "[PipedriveClient] Found user: #{user ? user['id'] : 'N/A'}"
    user&.dig('id')
  rescue => e
    Rails.logger.error("Pipedrive find_user_id_by_name error: #{e.message}")
    nil
  end

  def find_stage_id_by_name(name)
    response = get(ENDPOINTS[:stages])
    return nil unless response&.dig('success') && response['data'].present?
    
    stage = response['data'].find { |s| s['name'].casecmp(name).zero? }
    stage&.dig('id')
  rescue => e
    Rails.logger.error("Pipedrive find_stage_id_by_name error: #{e.message}")
    nil
  end

  def valid_search_response?(response)
    response&.dig('success') && response.dig('data', 'items')&.present?
  end

  def extract_id_from_search(response)
    return nil unless valid_search_response?(response)
    response['data']['items'].first['item']['id']
  end
end
