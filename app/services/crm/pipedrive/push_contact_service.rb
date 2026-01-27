class Crm::Pipedrive::PushContactService
  CACHE_EXPIRY = 1.minute

  def initialize(contact:)
    @contact = contact
    @account = contact.account
    @hook = @account.hooks.find_by(app_id: 'pipedrive')
  end

  def perform
    return unless should_sync?

    @client = build_client
    pipedrive_id = find_or_resolve_pipedrive_id

    pipedrive_id ? update_person(pipedrive_id) : create_person
  end

  private

  def should_sync?
    @hook&.settings&.dig('sync_contacts')
  end

  def build_client
    PipedriveClient.new(
      base_url: @hook.settings['pipedrive_url'],
      api_token: @hook.settings['api_token']
    )
  end

  def find_or_resolve_pipedrive_id
    @contact.additional_attributes['pipedrive_id'] || search_person_id
  end

  def search_person_id
    found = find_person_in_pipedrive
    found&.dig('id')
  end

  def find_person_in_pipedrive
    search_by_phone || search_by_email
  end

  def search_by_phone
    return nil unless @contact.phone_number.present?
    search_person(@contact.phone_number)
  end

  def search_by_email
    return nil unless @contact.email.present?
    search_person(@contact.email)
  end

  def search_person(term)
    res = @client.search_person(term: term)
    extract_first_person(res) if valid_search_result?(res)
  end

  def valid_search_result?(res)
    res&.dig('success') && res.dig('data', 'items')&.present?
  end

  def extract_first_person(res)
    res['data']['items'].first['item']
  end

  def create_person
    res = @client.create_person(build_create_payload)
    
    if res&.dig('success')
      pipedrive_id = res['data']['id']
      mark_as_chatwoot_source(pipedrive_id)
      store_pipedrive_id(pipedrive_id)
    end
  end

  def build_create_payload
    {
      name: contact_name,
      email: sync_email? ? @contact.email : nil,
      phone: sync_phone? ? @contact.phone_number : nil
    }.tap do |payload|
      payload[:org_id] = resolve_org_id if sync_org?
    end.compact
  end

  def contact_name
    @contact.name || @contact.phone_number || @contact.email
  end

  def update_person(id)
    remote_person = fetch_remote_person(id)
    return unless remote_person

    payload = build_update_payload(remote_person)
    return log_no_changes if payload.empty?

    log_update(id, payload)
    perform_update(id, payload)
  end

  def fetch_remote_person(id)
    res = @client.person_details(id: id)
    res['data'] if res&.dig('success')
  end

  def build_update_payload(remote_data)
    {}.tap do |payload|
      add_name_to_payload(payload, remote_data) if sync_name?
      add_email_to_payload(payload, remote_data) if sync_email?
      add_phone_to_payload(payload, remote_data) if sync_phone?
      add_org_to_payload(payload, remote_data) if sync_org?
    end
  end

  def add_name_to_payload(payload, remote_data)
    return unless @contact.name.present? && @contact.name != remote_data['name']
    payload[:name] = @contact.name
  end

  def add_email_to_payload(payload, remote_data)
    return unless @contact.email.present?
    
    remote_emails = extract_values(remote_data['email'])
    payload[:email] = @contact.email unless remote_emails.include?(@contact.email)
  end

  def add_phone_to_payload(payload, remote_data)
    return unless @contact.phone_number.present?
    
    remote_phones = extract_values(remote_data['phone'])
    payload[:phone] = @contact.phone_number unless remote_phones.include?(@contact.phone_number)
  end

  def add_org_to_payload(payload, remote_data)
    org_id = resolve_org_id
    payload[:org_id] = org_id if org_id && org_id != remote_data['org_id']
  end

  def extract_values(array)
    (array || []).map { |item| item['value'] }
  end

  def log_no_changes
    Rails.logger.info "[Pipedrive] Skipping Contact ##{@contact.id} - no changes vs Pipedrive"
  end

  def log_update(id, payload)
    Rails.logger.info "[Pipedrive] Updating Contact ##{@contact.id} (Pipedrive: #{id}). Payload: #{payload.inspect}"
  end

  def perform_update(id, payload)
    res = @client.update_person(id: id, payload: payload)
    mark_as_chatwoot_source(id) if res&.dig('success')
  end

  def mark_as_chatwoot_source(pipedrive_id)
    Rails.cache.write("chatwoot_source_#{pipedrive_id}", true, expires_in: CACHE_EXPIRY)
  end

  def store_pipedrive_id(pipedrive_id)
    @contact.additional_attributes['pipedrive_id'] = pipedrive_id
    @contact.save
  end

  def resolve_org_id
    company_name = @contact.additional_attributes['company_name']
    return nil unless company_name.present?

    normalized_name = normalize_company_name(company_name)
    
    Rails.logger.info "[Pipedrive] Resolving organization '#{company_name}' (normalized: '#{normalized_name}')"

    find_existing_org(normalized_name) || create_new_org(company_name)
  rescue => e
    Rails.logger.warn "[Pipedrive] Failed to resolve organization: #{e.class} - #{e.message}"
    nil
  end

  def normalize_company_name(name)
    name.strip.squeeze(' ')
  end

  def find_existing_org(normalized_name)
    res = @client.search_organization(term: normalized_name)
    return nil unless res&.dig('success') && res.dig('data', 'items')&.present?

    find_exact_or_similar_match(res['data']['items'], normalized_name)
  end

  def find_exact_or_similar_match(items, normalized_name)
    exact_match = find_exact_match(items, normalized_name)
    return exact_match if exact_match

    find_similar_match(items, normalized_name)
  end

  def find_exact_match(items, normalized_name)
    match = items.find do |i|
      org_name = normalize_company_name(i['item']['name'].to_s)
      org_name.casecmp?(normalized_name)
    end

    return nil unless match

    org_id = match['item']['id']
    org_name = match['item']['name']
    
    Rails.logger.info "[Pipedrive] Found exact match: Org ID=#{org_id}, Name='#{org_name}'"
    update_org_name_if_changed(org_id, org_name, @contact.additional_attributes['company_name'])
    
    org_id
  end

  def find_similar_match(items, normalized_name)
    first = items.first
    first_org_name = normalize_company_name(first['item']['name'].to_s)

    return nil unless similar_names?(first_org_name, normalized_name)

    org_id = first['item']['id']
    Rails.logger.info "[Pipedrive] Using similar match: Org ID=#{org_id}, Name='#{first_org_name}'"
    
    update_org_name_if_changed(org_id, first_org_name, @contact.additional_attributes['company_name'])
    
    org_id
  end

  def similar_names?(name1, name2)
    name1.casecmp?(name2) ||
    name1.downcase.include?(name2.downcase) ||
    name2.downcase.include?(name1.downcase)
  end

  def update_org_name_if_changed(org_id, current_name, target_name)
    return if current_name == target_name

    Rails.logger.info "[Pipedrive] Updating org name from '#{current_name}' to '#{target_name}'"
    res = @client.update_organization(id: org_id, payload: { name: target_name })
    Rails.logger.warn "[Pipedrive] Failed to update org name" unless res&.dig('success')
  end

  def create_new_org(company_name)
    Rails.logger.info "[Pipedrive] Creating new organization '#{company_name}'"
    
    res = @client.create_organization(name: company_name)
    return nil unless res&.dig('success')

    org_id = res['data']['id']
    Rails.logger.info "[Pipedrive] Created organization: ID=#{org_id}"
    org_id
  end

  def settings
    @settings ||= @hook.settings || {}
  end

  def sync_phone?
    settings['sync_phone'] != false
  end

  def sync_email?
    settings['sync_email'] != false
  end

  def sync_name?
    settings['sync_name'] != false
  end

  def sync_org?
    settings['sync_organization'] != false
  end
end
