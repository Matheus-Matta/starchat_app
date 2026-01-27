class Crm::Pipedrive::BrowseResourcesService
  DEFAULT_LIMIT = 15
  EXCLUDED_STATUSES_FOR_V2 = ['all_not_deleted', 'open'].freeze

  def initialize(account:, params:)
    @account = account
    @params = params.dup
    @hook = @account.hooks.find_by(app_id: 'pipedrive')
    @advanced_conditions = []
    @use_filter_api = false

    apply_rich_filters if @params[:filters].present?
  end

  def deals
    return api_error unless client

    response = if search_mode?
                 search_deals
               elsif filter_mode?
                 filter_deals
               else
                 standard_deals
               end
    format_response(response, type: :deal)
  end

  def leads
    return api_error unless client

    response = if search_mode?
                 search_leads
               elsif filter_mode?
                 filter_leads
               else
                 standard_leads
               end
    format_response(response, type: :lead)
  end

  def activities
    return api_error unless client

    response = if search_mode?
                 search_activities
               elsif filter_mode?
                 filter_activities
               else
                 standard_activities
               end
    format_response(response, type: :activity)
  end

  def filters
    return api_error unless client
    format_response(client.filters(type: @params[:type]))
  end

  def users
    return api_error unless client
    
    response = client.get('/v1/users', params: {})
    return api_error unless response&.dig('success')

    users = response['data'] || []
    users = filter_by_term(users, @params[:term]) if @params[:term].present?
    
    { payload: users.first(5).map { |u| { id: u['id'], name: u['name'], email: u['email'] } } }
  rescue => e
    { error: e.message }
  end

  def persons
    return api_error unless client
    
    term = @params[:term] || ''
    items = term.present? ? search_persons(term) : list_persons
    
    { payload: items.map { |p| person_payload(p) } }
  rescue => e
    { error: e.message }
  end

  def organizations
    return api_error unless client
    
    term = @params[:term] || ''
    items = term.present? ? search_organizations(term) : list_organizations
    
    { payload: items.map { |o| { id: o['id'], name: o['name'] } } }
  rescue => e
    { error: e.message }
  end

  def lead_labels
    return api_error unless client
    
    response = client.lead_labels
    return api_error unless response&.dig('success')
    
    { payload: response['data'] || [] }
  rescue => e
    { error: e.message }
  end

  def search_products(term)
    return api_error unless client
    
    if term.present?
      response = client.search_products(term: term, limit: 5)
      items = (response.dig('data', 'items') || []).map { |i| i['item'] }
    else
      response = client.products(limit: 5)
      items = response['data'] || []
    end

    return { payload: [] } unless response&.dig('success')
    
    products = items.map do |p| 
      { 
        id: p['id'], 
        name: p['name'], 
        price: p['prices']&.first&.dig('price') 
      } 
    end
       
    { payload: products }
  rescue => e
    { error: e.message }
  end

  private

  def client
    return nil unless @hook&.settings&.dig('api_token')
    @client ||= PipedriveClient.new(base_url: @hook.settings['pipedrive_url'], api_token: @hook.settings['api_token'])
  end

  def api_error
    { error: 'Not connected' }
  end

  def search_mode?
    @params[:search].present?
  end

  def filter_mode?
    @use_filter_api && @advanced_conditions.any?
  end

  def search_deals
    response = client.deals_search(term: @params[:search], start: pagination[:start], limit: pagination[:limit])
    return api_error unless response
    format_response(response, is_search: true)
  end

  def filter_deals
    filter_id = ensure_filter_id('deals')
    return { error: 'Filter Creation Failed' } unless filter_id

    client.deals(filter_id: filter_id, start: pagination[:start], limit: pagination[:limit], sort: sort_param_string)
  end

  def standard_deals
    api_args = {
      limit: pagination[:limit],
      start: pagination[:start],
      status: @params[:status] || 'all_not_deleted',
      sort: sort_param_string,
      owner_id: @params[:owner_id],
      stage_id: @params[:stage_id],
      person_id: @params[:person_id],
      org_id: @params[:org_id]
    }
    client.deals(**api_args)
  end

  def search_leads
    client.leads_search(term: @params[:search], start: pagination[:start], limit: pagination[:limit])
  end

  def filter_leads
    filter_id = ensure_filter_id('leads')
    return { error: 'Filter Creation Failed' } unless filter_id

    client.leads(filter_id: filter_id, start: pagination[:start], limit: pagination[:limit], sort: sort_param_string)
  end

  def standard_leads
    api_args = {
      limit: pagination[:limit],
      start: pagination[:start],
      sort: sort_param_string,
      owner_id: @params[:owner_id],
      person_id: @params[:person_id],
      organization_id: @params[:organization_id]
    }
    
    api_args[:archived_status] = 'archived' if @params[:status] == 'archived'

    client.leads(**api_args)
  end

  def search_activities
    client.activities_search(term: @params[:search], start: pagination[:start], limit: pagination[:limit])
  end

  def filter_activities
    filter_id = ensure_filter_id('activity')
    return { error: 'Filter Creation Failed' } unless filter_id
    
    client.activities(filter_id: filter_id, start: pagination[:start], limit: pagination[:limit])
  end

  def standard_activities
    api_args = {
      limit: pagination[:limit],
      start: pagination[:start],
      done: @params[:done],
      sort_by: @params[:sort_by],
      sort_direction: @params[:sort_direction],
      owner_id: @params[:owner_id],
      person_id: @params[:person_id],
      org_id: @params[:org_id],
      type: @params[:type],
      start_date: @params[:start_date],
      end_date: @params[:end_date]
    }
    client.activities(**api_args)
  end

  def pagination
    { start: (@params[:start] || 0).to_i, limit: (@params[:limit] || DEFAULT_LIMIT).to_i }
  end

  def search_persons(term)
    response = client.get('/api/v2/persons/search', params: { term: term, limit: 5 })
    return [] unless response&.dig('success')
    (response.dig('data', 'items') || []).map { |i| i['item'] }
  end

  def list_persons
    response = client.get('/v1/persons', params: { limit: 5 })
    return [] unless response&.dig('success')
    response['data'] || []
  end

  def search_organizations(term)
    response = client.get('/api/v2/organizations/search', params: { term: term, limit: 5 })
    return [] unless response&.dig('success')
    (response.dig('data', 'items') || []).map { |i| i['item'] }
  end

  def list_organizations
    response = client.get('/v1/organizations', params: { limit: 5 })
    return [] unless response&.dig('success')
    response['data'] || []
  end

  def person_payload(person)
    emails = person['emails'] || []
    primary_email = emails.find { |e| e['primary'] } || emails.first
    email_val = primary_email.is_a?(Hash) ? primary_email['value'] : primary_email

    phones = person['phones'] || []
    primary_phone = phones.find { |p| p['primary'] } || phones.first
    phone_val = primary_phone.is_a?(Hash) ? primary_phone['value'] : primary_phone

    { 
      id: person['id'], 
      name: person['name'], 
      email: email_val, 
      phone: phone_val
    }
  end

  def filter_by_term(users, term)
    term_lower = term.downcase
    users.select { |u| u['name']&.downcase&.include?(term_lower) || u['email']&.downcase&.include?(term_lower) }
  end

  def apply_rich_filters
    raw = @params[:filters]
    return if raw.blank?
    
    normalized = normalize_filters(raw)
    return unless normalized.is_a?(Array)

    normalized.each { |filter| process_filter(filter) }
  end

  def process_filter(filter)
    filter = filter.with_indifferent_access if filter.respond_to?(:with_indifferent_access)
    
    key = filter[:attributeKey]
    val = extract_filter_value(filter[:value])
    
    return if val.blank?

    case key
    when 'status'      then apply_status_filter(val)
    when 'owner_id', 'user_id' then apply_owner_filter(val)
    when 'person_id'   then apply_person_filter(val)
    when 'org_id'      then apply_org_filter(val)
    when 'type'        then apply_type_filter(val)
    when 'done'        then apply_done_filter(val)
    when 'due_date'    then apply_due_date_filter(val)
    when 'created_from' then apply_date_range_filter('add_time', '>=', val)
    when 'created_to'   then apply_date_range_filter('add_time', '<=', val)
    when 'updated_from' then apply_date_range_filter('update_time', '>=', val)
    when 'updated_to'   then apply_date_range_filter('update_time', '<=', val)
    end
  end

  def extract_filter_value(value)
    return value unless value.is_a?(Hash)
    value['id'] || value[:id] || value['value'] || value[:value]
  end

  def apply_status_filter(val)
    @params[:status] = val
    add_advanced_condition('status', '=', val)
  end

  def apply_owner_filter(val)
    @params[:owner_id] = val.to_i
    add_advanced_condition('user_id', '=', val.to_i)
  end

  def apply_person_filter(val)
    @params[:person_id] = val.to_i
    add_advanced_condition('person_id', '=', val.to_i)
  end

  def apply_org_filter(val)
    @params[:org_id] = val.to_i
    @params[:organization_id] = val.to_i
    add_advanced_condition('org_id', '=', val.to_i)
  end

  def apply_type_filter(val)
    @params[:type] = val
    add_advanced_condition('type', '=', val)
  end

  def apply_done_filter(val)
    bool_val = ['true', true, '1'].include?(val)
    @params[:done] = bool_val ? 1 : 0
    add_advanced_condition('done', '=', @params[:done])
  end

  def apply_due_date_filter(val)
    date = parse_date(val)
    @params[:start_date] = date
    @params[:end_date] = date
    add_advanced_condition('due_date', '=', date)
  end

  def apply_date_range_filter(field, operator, val)
    @use_filter_api = true
    add_advanced_condition(field, operator, parse_date(val))
  end

  def add_advanced_condition(field, operator, value)
    @advanced_conditions << { field: field, operator: operator, value: value }
  end

  def normalize_filters(filters)
    filters = parse_json_if_string(filters)
    filters = filters.to_unsafe_h if filters.respond_to?(:to_unsafe_h)

    return filters['payload'] if filters.is_a?(Hash) && filters['payload'].present?
    return filters.values if filters.is_a?(Hash)
    
    filters
  end

  def parse_json_if_string(filters)
    return filters unless filters.is_a?(String)
    JSON.parse(filters)
  rescue JSON::ParserError
    []
  end

  def sort_param_string
    return nil unless @params[:sort_by].present?
    direction = @params[:sort_direction] || 'desc'
    "#{@params[:sort_by]} #{direction}".strip
  end

  def parse_date(val)
    return nil if val.blank?
    Date.parse(val.to_s).strftime('%Y-%m-%d')
  rescue
    nil
  end

  def ensure_filter_id(resource_type)
    filter_name = "[Chatwoot] #{resource_type.capitalize} Filter"
    existing = find_filter_by_name(filter_name, resource_type)
    conditions_json = build_conditions_json(@advanced_conditions)

    if existing
      update_filter(existing['id'], conditions_json)
    else
      create_filter(filter_name, resource_type, conditions_json)
    end
  end

  def update_filter(filter_id, conditions_json)
    response = client.put("/v1/filters/#{filter_id}", payload: { conditions: conditions_json })
    filter_id if response&.dig('success')
  end

  def create_filter(name, resource_type, conditions_json)
    payload = { name: name, type: resource_type, conditions: conditions_json, visible_to: 3 }
    response = client.post('/v1/filters', payload: payload)
    response['data']['id'] if response&.dig('success')
  end

  def find_filter_by_name(name, type)
    response = client.filters(type: type)
    return nil unless response&.dig('success')
    
    response['data'].find { |f| f['name'] == name }
  end

  def build_conditions_json(conditions)
    children = conditions.map do |c|
      { object: '', field: c[:field], operator: c[:operator], value: c[:value] }
    end

    { glues: { type: 'AND', children: children } }
  end

  def format_response(response, type: nil)
    return { error: 'API Connection Error' } if response.nil?
    is_search = @params[:search].present?

    if response['success']
      data = is_search ? extract_search_data(response) : extract_standard_data(response)
      
      data = inject_pipedrive_links(data, type) if type

      {
        payload: data,
        meta: {
          more_items_in_collection: response.dig('additional_data', 'pagination', 'more_items_in_collection'),
          start: response.dig('additional_data', 'pagination', 'start'),
          limit: response.dig('additional_data', 'pagination', 'limit'),
          count: data.size,
          total: response.dig('additional_data', 'summary', 'total_count')
        }
      }
    else
      { error: response['error'] || 'API Error' }
    end
  rescue => e
    { error: e.message }
  end

  def inject_pipedrive_links(data, type)
    base_url = @hook.settings['company_domain'] ? "https://#{@hook.settings['company_domain']}.pipedrive.com" : @hook.settings['pipedrive_url']
    base_url = "https://app.pipedrive.com" if base_url.blank? || base_url.include?('api')

    data.map do |item|
      id = item['id']
      link = case type
             when :deal then "#{base_url}/deal/#{id}"
             when :lead then "#{base_url}/leads/inbox/#{id}"
             when :activity then "#{base_url}/activities/list/user/everyone?selected_activity_id=#{id}&tab=activity"
             else nil
             end
      item.merge('pipedrive_link' => link)
    end
  end

  def extract_search_data(response)
    (response.dig('data', 'items') || []).map { |i| i['item'] }
  end

  def extract_standard_data(response)
    response['data'] || []
  end
end
