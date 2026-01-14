# frozen_string_literal: true
require "json"
require "faraday"

class PipedriveClient
  # Endpoints v1
  ENDPOINTS = {
    persons_search: "/v1/persons/search",
    persons:        "/v1/persons",
    person_details: "/v1/persons/%{id}",
    person_fields:  "/v1/personFields",
    deals:          "/v1/deals",
    activities:     "/v1/activities",
    deals_search:   "/v1/deals/search",
    leads_search:   "/v1/leads/search",
    leads:          "/v1/leads",
    notes:          "/v1/notes",
    organization:   "/v1/organizations/%{id}",
    stages:         "/v1/stages",
    deal_fields:    "/v1/dealFields",
    lead_labels:    "/v1/leadLabels",
    webhooks:       "/v1/webhooks",
    organizations_search: "/v1/organizations/search",
    organizations:        "/v1/organizations",
    filters:              "/v1/filters",
    users:                "/v1/users"
  }.freeze

  def initialize(base_url:, api_token:)
    @conn = Faraday.new(url: base_url) do |f|
      f.request :json
      f.response :raise_error
      f.adapter Faraday.default_adapter
    end
    @api_token = api_token
  end

  def filters(type:)
    get(ENDPOINTS[:filters], params: { type: type })
  end

  def get(path, params: {})
    resp = @conn.get(path) do |req|
      # Some Pipedrive endpoints require api_token in query param (v1/v2 inconsistency)
      # We add it in query param to be safe as per legacy docs, and keep header if supported.
      req.params['api_token'] = @api_token
      req.params.update(params)
    end
    JSON.parse(resp.body)
  rescue Faraday::Error => e
    # Log error or re-raise wrapped error
    Rails.logger.error("Pipedrive API Error: #{e.message}")
    nil
  end

  # 1) Search person by phone/email
  def search_person(term:, fields: "phone,email", exact_match: true, limit: 10)
    get(
      ENDPOINTS[:persons_search],
      params: { term: term, fields: fields, exact_match: exact_match, limit: limit }
    )
  end

  # 2) Person details + counts
  def person_details(id:, include_fields: nil, custom_fields: nil)
    path = ENDPOINTS[:person_details] % { id: id }
    params = {}
    params[:include_fields] = include_fields if include_fields
    params[:custom_fields] = custom_fields if custom_fields
    get(path, params: params)
  end

  # 3) Deals by person_id
  # 3) Deals by person_id or other filters
  def deals(person_id: nil, filter_id: nil, user_id: nil, owner_id: nil, stage_id: nil, org_id: nil, status: "open", start: 0, limit: 100, sort: nil, user_name: nil, stage_name: nil, person_name: nil, org_name: nil, get_summary: nil)
    params = { status: status, start: start, limit: limit, get_summary: get_summary }
    
    # Resolve Names to IDs if names provided
    owner_id  ||= find_user_id_by_name(user_name) if user_name.present?
    stage_id  ||= find_stage_id_by_name(stage_name) if stage_name.present?
    person_id ||= find_person_id_by_name(person_name) if person_name.present?
    org_id    ||= find_org_id_by_name(org_name) if org_name.present?

    # Pipedrive API uses user_id for owner filtering in /deals
    final_user_id = owner_id || user_id

    params[:person_id] = person_id if person_id
    params[:filter_id] = filter_id if filter_id
    params[:user_id]   = final_user_id if final_user_id
    params[:stage_id]  = stage_id if stage_id
    params[:org_id]    = org_id if org_id
    params[:sort]      = sort if sort
    
    get(ENDPOINTS[:deals], params: params)
  end

  # 4) Activities with extensive filters
  def activities(filter_id: nil, ids: nil, owner_id: nil, deal_id: nil, lead_id: nil, person_id: nil, org_id: nil, done: nil, updated_since: nil, updated_until: nil, start_date: nil, end_date: nil, sort_by: "due_date", sort_direction: "asc", include_fields: nil, limit: 100, start: 0, cursor: nil, user_name: nil, person_name: nil, org_name: nil, get_summary: nil)
    params = {
      limit: limit,
      start: start,
      sort_by: sort_by,
      sort_direction: sort_direction,
      get_summary: get_summary
    }

    # Resolve Names
    owner_id  ||= find_user_id_by_name(user_name) if user_name.present?
    person_id ||= find_person_id_by_name(person_name) if person_name.present?
    org_id    ||= find_org_id_by_name(org_name) if org_name.present?

    # Map owner_id argument to user_id param (Pipedrive API activities uses user_id)
    Rails.logger.info "[PipedriveClient] Activities filter - Name: #{user_name}, Resolved Owner ID: #{owner_id}" if user_name.present?
    
    
    # NOTE: The Pipedrive API documentation can be inconsistent. 
    # For /v1/activities, filtering by 'user_id' filters by the assigned user (owner).
    if owner_id
      params[:user_id] = owner_id 
    end
    params[:filter_id]      = filter_id if filter_id
    params[:ids]            = ids if ids
    params[:deal_id]        = deal_id if deal_id
    params[:lead_id]        = lead_id if lead_id
    params[:person_id]      = person_id if person_id
    params[:org_id]         = org_id if org_id
    params[:done]           = done if done
    params[:startDate]      = start_date if start_date
    params[:endDate]        = end_date if end_date
    params[:updated_since]  = updated_since if updated_since
    params[:updated_until]  = updated_until if updated_until
    params[:include_fields] = include_fields if include_fields
    params[:cursor]         = cursor if cursor

    get(ENDPOINTS[:activities], params: params)
  end

  def activities_search(term:, start: 0, limit: 50)
    # 1. Try finding by Person Name
    person_id = find_person_id_by_name(term)
    return activities(person_id: person_id, start: start, limit: limit) if person_id

    # 2. Try finding by Org Name
    org_id = find_org_id_by_name(term)
    return activities(org_id: org_id, start: start, limit: limit) if org_id

    # 3. No match found, return empty successful response
    { 'success' => true, 'data' => [], 'additional_data' => { 'pagination' => { 'start' => start, 'limit' => limit, 'more_items_in_collection' => false }, 'summary' => { 'total_count' => 0 } } }
  end

  # 5) Leads search
  def leads_search(term:, person_id: nil, start: 0, limit: 50)
    params = { term: term, start: start, limit: limit }
    params[:person_id] = person_id if person_id
    get(ENDPOINTS[:leads_search], params: params)
  end

  def deals_search(term:, start: 0, limit: 50)
     get(ENDPOINTS[:deals_search], params: { term: term, start: start, limit: limit })
  end

  # 5b) Leads list by person_id or filters
  def leads(person_id: nil, org_id: nil, organization_id: nil, title: nil, owner_id: nil, archived_status: nil, start: 0, limit: 50, sort: nil, user_name: nil, person_name: nil, org_name: nil, get_summary: nil)
     params = {
        start: start,
        limit: limit,
        get_summary: get_summary
     }

     owner_id  ||= find_user_id_by_name(user_name) if user_name.present?
     person_id ||= find_person_id_by_name(person_name) if person_name.present?
     org_id    ||= find_org_id_by_name(org_name) if org_name.present?

     # Handle organization_id alias
     final_org_id = organization_id || org_id

     params[:person_id] = person_id if person_id
     params[:organization_id] = final_org_id if final_org_id
     params[:title]     = title if title
     params[:owner_id]  = owner_id if owner_id
     params[:archived_status] = archived_status if archived_status
     params[:sort]      = sort if sort

     get(ENDPOINTS[:leads], params: params)
  end

  # 6) Notes (v1)
  def notes(person_id:, limit: 50)
    get(ENDPOINTS[:notes], params: { person_id: person_id, limit: limit, sort: "update_time DESC" })
  end
  # 7) Organization Details
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
    payload[:email] = email if email
    payload[:phone] = phone if phone
    payload[:org_id] = org_id if org_id
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
    post(
      ENDPOINTS[:webhooks],
      payload: {
        subscription_url: subscription_url,
        event_action: event_action,
        event_object: event_object,
        user_id: nil # Admin user
      }
    )
  end

  def delete_webhook(id:)
    delete("#{ENDPOINTS[:webhooks]}/#{id}")
  end

  def search_organization(term:, limit: 10)
    get(ENDPOINTS[:organizations_search], params: { term: term, limit: limit })
  end

  def create_organization(payload)
    post(ENDPOINTS[:organizations], payload)
  end

  def update_organization(id:, payload:)
    put("#{ENDPOINTS[:organizations]}/#{id}", payload)
  end

  private

  def find_person_id_by_name(name)
    response = get(ENDPOINTS[:persons_search], params: { term: name, limit: 1 })
    return nil unless response && response['success'] && response['data'] && response['data']['items'].present?
    
    response['data']['items'].first['item']['id']
  rescue => e
    Rails.logger.error("Pipedrive find_person_id_by_name error: #{e.message}")
    nil
  end

  def find_org_id_by_name(name)
    response = get(ENDPOINTS[:organizations_search], params: { term: name, limit: 1 })
    return nil unless response && response['success'] && response['data'] && response['data']['items'].present?
    
    response['data']['items'].first['item']['id']
  rescue => e
    Rails.logger.error("Pipedrive find_org_id_by_name error: #{e.message}")
    nil
  end

  def find_user_id_by_name(name)
    response = get(ENDPOINTS[:users])
    return nil unless response && response['success'] && response['data'].present?
    
    Rails.logger.info "[PipedriveClient] Searching for user: #{name}"
    user = response['data'].find { |u| u['name'].casecmp(name).zero? || u['email'].casecmp(name).zero? }
    Rails.logger.info "[PipedriveClient] Found user: #{user ? user['id'] : 'N/A'}"
    user ? user['id'] : nil
  rescue => e
    Rails.logger.error("Pipedrive find_user_id_by_name error: #{e.message}")
    nil
  end

  def find_stage_id_by_name(name)
    response = get(ENDPOINTS[:stages])
    return nil unless response && response['success'] && response['data'].present?
    
    stage = response['data'].find { |s| s['name'].casecmp(name).zero? }
    stage ? stage['id'] : nil
  rescue => e
    Rails.logger.error("Pipedrive find_stage_id_by_name error: #{e.message}")
    nil
  end


  def delete(path)
    resp = @conn.delete(path) do |req|
      req.params['api_token'] = @api_token
    end
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
      req.body = body.to_json
    end
    JSON.parse(resp.body)
  rescue Faraday::Error => e
    Rails.logger.error("Pipedrive API Error: #{e.message}")
    nil
  end
end
