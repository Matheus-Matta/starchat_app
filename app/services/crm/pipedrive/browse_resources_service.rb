class Crm::Pipedrive::BrowseResourcesService
  def initialize(account:, params:)
    @account = account
    @params = params.dup # Dup to allow mutation
    @hook = @account.hooks.find_by(app_id: 'pipedrive')
    
    # Pre-process rich filters if present via the Translator Layer
    apply_rich_filters if @params[:filters].present?
  end

  private

  # TRANSLATOR LAYER
  # Converts the frontend "Rich Payload" (standardized JSON) into 
  # Pipedrive-compatible API parameters (flat key-values).
  def apply_rich_filters
    raw_filters = @params[:filters]
    return if raw_filters.blank?

    # 1. Normalize Input: Handles JSON strings, ActionController::Parameters, and Hashes
    # This ensures we always end up with a flat Array of filter objects
    normalized_filters = normalize_filters(raw_filters)
    return unless normalized_filters.is_a?(Array)

    # 2. Translate Filters
    normalized_filters.each do |filter|
      # Safe access to hash with symbol/string keys
      filter = filter.with_indifferent_access if filter.respond_to?(:with_indifferent_access)
      
      key = filter[:attributeKey]
      val = filter[:value]

      # Extract ID if value is an object (common in select filters)
      if val.is_a?(Hash)
         val = val['id'] || val[:id] || val['value'] || val[:value]
      end

      next if val.blank?

      # 3. Map to Pipedrive API Parameters
      # We map specific frontend keys to the parameters expected by our PipedriveClient methods
      case key
      when 'status'
        @params[:status] = val
      when 'owner_id', 'user_id' # 'user_id' is legacy support, 'owner_id' is correct semantic
        @params[:owner_id] = val.to_i
      when 'person_id'
        @params[:person_id] = val.to_i
      when 'org_id', 'organization_id'
        @params[:org_id] = val.to_i
      when 'stage_id', 'stage_name'
        @params[:stage_id] = val.to_i
      when 'type' # Activity Type
        @params[:type] = val
      when 'due_date'
        @params[:due_date] = val
      end
    end
  end

  def normalize_filters(filters)
    # Handle JSON String
    if filters.is_a?(String)
      begin
        filters = JSON.parse(filters)
      rescue JSON::ParserError
        return []
      end
    end

    # Handle Rails Parameters / Hash map (e.g. from Rack parsing indexed forms)
    if filters.respond_to?(:to_unsafe_h)
      filters = filters.to_unsafe_h
    end

    if filters.is_a?(Hash)
      # If wrapped in "payload" key
      if filters['payload'].present?
        return filters['payload']
      else
        # If indexed hash {"0" => {...}, "1" => {...}}
        return filters.values
      end
    end

    filters
  end

  public

  def deals
    return { error: 'Not connected' } unless client

    if @params[:search].present?
      response = client.deals_search(
        term: @params[:search],
        start: @params[:start] || 0,
        limit: @params[:limit] || 5
      )
      return { error: 'API Error' } unless response
      format_response(response, is_search: true)
    else
      # Sort parameter construction
      sort_param = nil
      if @params[:sort_by].present?
        direction = @params[:sort_direction] || 'desc'
        sort_param = "#{@params[:sort_by]} #{direction}".strip
      end
  
      # API Call directly using translated params
      # Note: PipedriveClient deals method expects: owner_id for user filter
      api_args = {
        limit: @params[:limit] || 5,
        start: @params[:start] || 0,
        status: @params[:status] || 'all_not_deleted',
        sort: sort_param,
        owner_id: @params[:owner_id],
        stage_id: @params[:stage_id],
        person_id: @params[:person_id],
        org_id: @params[:org_id],
        get_summary: 1
      }

      response = client.deals(**api_args)
      return { error: 'API Error' } unless response
      
      format_response(response)
    end
  end

  def leads
    return { error: 'Not connected' } unless client

    if @params[:search].present?
      response = client.leads_search(
        term: @params[:search],
        start: @params[:start] || 0,
        limit: @params[:limit] || 5
      )
      return { error: 'API Error' } unless response

      # Normalize search results structure for Leads
      if response['success'] && response['data'] && response['data']['items']
        response['data']['items'].each do |wrapper|
          item = wrapper['item']
          next unless item

          if item['person'].is_a?(Hash)
            item['person_name'] = item['person']['name']
            item['person_id']   = item['person']['id']
          end

          if item['organization'].is_a?(Hash)
            item['organization_name'] = item['organization']['name']
            item['organization_id']   = item['organization']['id']
          end

          unless item['value'].is_a?(Hash)
            item['value'] = {
              'amount' => item['value'],
              'currency' => item['currency']
            }
          end
        end
      end

      format_response(response, is_search: true)
    else
      sort_param = nil
      if @params[:sort_by].present?
        # Leads sort default typically asc
        direction = @params[:sort_direction] || 'asc'
        sort_param = "#{@params[:sort_by]} #{direction}".strip
      end
  
      # API Call
      api_args = {
        limit: @params[:limit] || 5,
        start: @params[:start] || 0,
        sort: sort_param,
        owner_id: @params[:owner_id],
        person_id: @params[:person_id],
        organization_id: @params[:org_id],
        get_summary: 1
      }

      response = client.leads(**api_args)
      return { error: 'API Error' } unless response
  
      format_response(response)
    end
  end

  def activities
    return { error: 'Not connected' } unless client

    if @params[:search].present?
      response = client.activities_search(
        term: @params[:search],
        start: @params[:start] || 0,
        limit: @params[:limit] || 5
      )
      return { error: 'API Error' } unless response
      format_response(response)
    else
      sort_param = nil
      if @params[:sort_by].present?
        direction = @params[:sort_direction] || 'desc'
        sort_param = "#{@params[:sort_by]} #{direction}".strip
      end

      # API Call
      api_args = {
        limit: @params[:limit] || 5,
        start: @params[:start] || 0,
        done: @params[:done],
        sort: sort_param,
        owner_id: @params[:owner_id], 
        person_id: @params[:person_id],
        org_id: @params[:org_id],
        type: @params[:type],
        due_date: @params[:due_date],
        get_summary: 1
      }

      response = client.activities(**api_args)
      return { error: 'API Error' } unless response

      format_response(response)
    end
  end

  def filters
    return { error: 'Not connected' } unless client

    response = client.filters(type: @params[:type])
    format_response(response)
  end

  def users
    return { error: 'Not connected' } unless client

    term = @params[:term] || ''
    
    # Get all users and filter by name or email
    response = client.get('/v1/users', params: {})
    return { error: 'API Error' } unless response && response['success']

    users = response['data'] || []
    
    # Filter by term if provided (search in name and email)
    if term.present?
      users = users.select do |user|
        user['name']&.downcase&.include?(term.downcase) ||
          user['email']&.downcase&.include?(term.downcase)
      end
    end
    
    # Limit to 5 results
    users = users.first(5).map do |user|
      { id: user['id'], name: user['name'], email: user['email'] }
    end

    { payload: users }
  rescue => e
    { error: e.message }
  end

  def persons
    return { error: 'Not connected' } unless client 

    term = @params[:term] || ''
    
    if term.present?
      # Use Pipedrive search endpoint for persons
      response = client.get('/v1/persons/search', params: { term: term, fields: 'name,email,phone', limit: 5 })
      return { error: 'API Error' } unless response && response['success']

      persons = (response.dig('data', 'items') || []).map do |item|
        person = item['item']
        { 
          id: person['id'], 
          name: person['name'],
          email: person['emails']&.first,
          phone: person['phones']&.first
        }
      end
    else
      # Get first 5 persons when no search term
      response = client.get('/v1/persons', params: { limit: 5 })
      return { error: 'API Error' } unless response && response['success']

      persons = (response['data'] || []).map do |person|
        { 
          id: person['id'], 
          name: person['name'],
          email: person['emails']&.first,
          phone: person['phones']&.first
        }
      end
    end

    { payload: persons }
  rescue => e
    { error: e.message }
  end

  def organizations
    return { error: 'Not connected' } unless client

    term = @params[:term] || ''
    
    if term.present?
      # Use Pipedrive search endpoint
      response = client.search_organization(term: term, limit: 5)
      return { error: 'API Error' } unless response && response['success']

      orgs = (response.dig('data', 'items') || []).map do |item|
        org = item['item']
        { id: org['id'], name: org['name'] }
      end
    else
      # Get first 5 organizations
      response = client.get('/v1/organizations', params: { limit: 5 })
      return { error: 'API Error' } unless response && response['success']

      orgs = (response['data'] || []).map do |org|
        { id: org['id'], name: org['name'] }
      end
    end

    { payload: orgs }
  rescue => e
    { error: e.message }
  end

  private

  def client
    return nil unless @hook && @hook.settings && @hook.settings['api_token']
    @client ||= PipedriveClient.new(base_url: @hook.settings['pipedrive_url'], api_token: @hook.settings['api_token'])
  end

  def format_response(response, is_search: false)
    if response['success']
      data = if is_search
               (response['data']['items'] || []).map { |i| i['item'] }
             else
               response['data'] || []
             end
      
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
end
