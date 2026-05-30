module Starchat::Account::PlanUsageAndLimits
  COSMOS_RESPONSES = 'cosmos_responses'.freeze
  COSMOS_DOCUMENTS = 'cosmos_documents'.freeze
  COSMOS_RESPONSES_USAGE = 'cosmos_responses_usage'.freeze
  COSMOS_DOCUMENTS_USAGE = 'cosmos_documents_usage'.freeze

  def usage_limits
    {
      agents: agent_limits.to_i,
      inboxes: get_limits(:inboxes).to_i,
      cosmos: {
        documents: get_cosmos_limits(:documents),
        responses: get_cosmos_limits(:responses)
      }
    }
  end

  def increment_response_usage
    current_usage = custom_attributes[COSMOS_RESPONSES_USAGE].to_i || 0
    custom_attributes[COSMOS_RESPONSES_USAGE] = current_usage + 1
    save
  end

  def reset_response_usage
    custom_attributes[COSMOS_RESPONSES_USAGE] = 0
    save
  end

  def update_document_usage
    # this will ensure that the document count is always accurate
    custom_attributes[COSMOS_DOCUMENTS_USAGE] = cosmos_documents.count
    save
  end

  def subscribed_features
    enabled_features.keys
  end

  def cosmos_monthly_limit
    default_limits = default_cosmos_limits

    {
      documents: self[:limits][COSMOS_DOCUMENTS] || default_limits['documents'],
      responses: self[:limits][COSMOS_RESPONSES] || default_limits['responses']
    }.with_indifferent_access
  end

  private

  def get_cosmos_limits(type)
    total_count = cosmos_monthly_limit[type.to_s].to_i

    consumed = if type == :documents
                 custom_attributes[COSMOS_DOCUMENTS_USAGE].to_i || 0
               else
                 custom_attributes[COSMOS_RESPONSES_USAGE].to_i || 0
               end

    consumed = 0 if consumed.negative?

    {
      total_count: total_count,
      current_available: (total_count - consumed).clamp(0, total_count),
      consumed: consumed
    }
  end

  def default_cosmos_limits
    max_limits = { documents: ChatwootApp.max_limit, responses: ChatwootApp.max_limit }.with_indifferent_access

    max_limits
  end

  def agent_limits
    subscribed_quantity = custom_attributes['subscribed_quantity']
    subscribed_quantity || get_limits(:agents)
  end

  def get_limits(limit_name)
    config_name = "ACCOUNT_#{limit_name.to_s.upcase}_LIMIT"
    return self[:limits][limit_name.to_s] if self[:limits][limit_name.to_s].present?

    return GlobalConfig.get(config_name)[config_name] if GlobalConfig.get(config_name)[config_name].present?

    ChatwootApp.max_limit
  end

  # Atomic jsonb_set to avoid clobbering concurrent writes to other custom_attributes keys.
  # Goes through Account relation (rather than raw connection) so shard routing is respected.
  # rubocop:disable Rails/SkipsModelValidations
  def update_custom_attribute(key, value)
    Account.where(id: id).update_all([
                                       "custom_attributes = jsonb_set(COALESCE(custom_attributes, '{}'), ARRAY[:key], :value::jsonb)",
                                       { key: key, value: value.to_json }
                                     ])
    custom_attributes[key] = value
  end

  def increment_custom_attribute(key)
    Account.where(id: id).update_all([
                                       "custom_attributes = jsonb_set(COALESCE(custom_attributes, '{}'), ARRAY[:key], " \
                                       '(COALESCE((custom_attributes ->> :key)::int, 0) + 1)::text::jsonb)',
                                       { key: key }
                                     ])
    custom_attributes[key] = custom_attributes[key].to_i + 1
  end
  # rubocop:enable Rails/SkipsModelValidations

  def validate_limit_keys
    errors.add(:limits, ': Invalid data') unless self[:limits].is_a? Hash
    self[:limits] = {} if self[:limits].blank?

    limit_schema = {
      'type' => 'object',
      'properties' => {
        'inboxes' => { 'type': 'number' },
        'agents' => { 'type': 'number' },
        'cosmos_responses' => { 'type': 'number' },
        'cosmos_documents' => { 'type': 'number' },
        'emails' => { 'type': 'number' }
      },
      'required' => [],
      'additionalProperties' => false
    }

    errors.add(:limits, ': Invalid data') unless JSONSchemer.schema(limit_schema).valid?(self[:limits])
  end
end
