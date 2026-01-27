# frozen_string_literal: true

class Crm::Pipedrive::ManageResourceService
  CUSTOM_FIELD_KEY_REGEX = /\A[a-f0-9]{40}\z/i

  def initialize(account:, params:)
    @account = account
    @params  = params
    @hook    = @account.hooks.find_by(app_id: "pipedrive")
  end

  # -------------------------
  # DEALS (v1)
  # -------------------------
  def update_deal
    return api_error unless client

    payload = normalize_hash(@params[:deal])
    payload = compact_deep_keep_false(payload)

    # Remove value/currency to avoid strict-mode / locked deal 400
    payload.delete("value")
    payload.delete("currency")
    payload.delete("amount")

    # Remove non-deal fields that cause 400
    excluded_fields = %w[
      product_id product_price product_quantity
      discount_description discount_amount discount_type
      installment_description installment_amount installment_date
    ]
    payload = payload.except(*excluded_fields)

    # Coerce common IDs
    coerce_int!(payload, %w[person_id org_id user_id stage_id pipeline_id])
    coerce_int!(payload, %w[visible_to probability])

    # Optional: normalize status casing if you use it
    payload["status"] = payload["status"].to_s.downcase if payload.key?("status")

    # Keep only allowed + custom fields (avoid random extra keys => 400)
    allowed_deal_fields = %w[
      title status lost_reason
      user_id person_id org_id stage_id pipeline_id
      visible_to probability
      expected_close_date
    ]
    payload = whitelist_with_custom_fields(payload, allowed_deal_fields)

    normalize_date_yyyy_mm_dd!(payload, "expected_close_date")

    Rails.logger.info("🔍 Pipedrive Update Deal Payload: #{payload.inspect}")
    client.update_deal(id: @params[:id], payload: payload)
  end

  def delete_deal
    return api_error unless client
    client.delete_deal(id: @params[:id])
  end

  # -------------------------
  # LEADS (v1)
  # -------------------------
  def update_lead
    return api_error unless client

    payload = normalize_hash(@params[:lead])
    payload = compact_deep_keep_false(payload)

    # Cast booleans (do NOT drop false)
    coerce_bool!(payload, %w[is_archived was_seen])

    # IDs
    coerce_int!(payload, %w[owner_id person_id organization_id channel])
    coerce_int!(payload, %w[visible_to]) # doc aceita "1/3/5/7" — int costuma passar melhor

    # label_ids must be array of integers
    payload["label_ids"] = normalize_int_array(payload["label_ids"]) if payload.key?("label_ids")

    # expected_close_date must be YYYY-MM-DD
    normalize_date_yyyy_mm_dd!(payload, "expected_close_date")

    # Lead value object: {amount, currency}
    # Only send if both amount + currency are present and valid
    if payload.key?("amount") || payload.key?("currency")
      amount   = payload["amount"]
      currency = payload["currency"].to_s.strip

      if amount.present? && currency.present?
        payload["value"] = { amount: amount.to_f, currency: currency }
      else
        # avoid sending invalid value => 400
        payload.delete("value")
      end
    end

    payload.delete("amount")
    payload.delete("currency")

    valid_fields = %w[
      title owner_id label_ids person_id organization_id is_archived
      value expected_close_date visible_to was_seen channel channel_id
    ]
    payload = whitelist_with_custom_fields(payload, valid_fields)

    Rails.logger.info("🔍 Pipedrive Update Lead Payload: #{payload.inspect}")
    client.update_lead(id: @params[:id], payload: payload)
  end

  def delete_lead
    return api_error unless client
    client.delete_lead(id: @params[:id])
  end

  # -------------------------
  # ACTIVITIES (v2 no seu client)
  # -------------------------
  def update_activity
    return api_error unless client

    Rails.logger.info "🔍 [Pipedrive] Incoming Activity Update Params: #{@params[:activity].to_unsafe_h.inspect}"

    payload = normalize_hash(@params[:activity])
    payload = compact_deep_keep_false(payload)

    # Map V2: owner_id (comes as user_id sometimes)
    target_owner_id = payload.delete('user_id') || payload['owner_id']
    if target_owner_id.present?
      payload['owner_id'] = normalize_int(target_owner_id)
    end

    # Booleans
    coerce_bool!(payload, %w[busy done])

    # Priority 0 -> remove
    payload.delete('priority') if payload['priority'].to_i.zero?

    normalize_date_yyyy_mm_dd!(payload, "due_date")
    normalize_hh_mm!(payload, "due_time")
    normalize_hh_mm!(payload, "duration")

    # Whitelist V2 (SEM person_id / org_id)
    valid_fields = %w[
      subject type owner_id deal_id lead_id project_id
      due_date due_time duration busy done location participants attendees
      public_description priority note
    ]
    payload = payload.slice(*valid_fields)

    # Safety: explicitly remove read-only fields that cause 400 on PATCH
    payload.except!("person_id", "org_id")

    # Coerce allowed IDs
    coerce_int!(payload, %w[deal_id lead_id project_id owner_id priority])

    Rails.logger.info("🔍 Pipedrive Update Activity Payload (V2): #{payload.inspect}")
    client.update_activity(id: @params[:id], payload: payload)
  end

  def delete_activity
    return api_error unless client
    client.delete_activity(id: @params[:id])
  end

  private

  def client
    return nil unless @hook&.settings&.dig("api_token")
    @client ||= PipedriveClient.new(
      base_url: @hook.settings["pipedrive_url"],
      api_token: @hook.settings["api_token"]
    )
  end

  def api_error
    { error: "Not connected" }
  end

  # ---------- Normalizers / Sanitizers ----------

  # Accepts ActionController::Parameters, Hash, nil
  def normalize_hash(obj)
    hash =
      if obj.respond_to?(:to_unsafe_h)
        obj.to_unsafe_h
      elsif obj.is_a?(Hash)
        obj
      else
        {}
      end

    hash.deep_stringify_keys
  end

  # Remove nil/blank strings/empty arrays/empty hashes but keep false
  def compact_deep_keep_false(obj)
    case obj
    when Hash
      obj.each_with_object({}) do |(k, v), h|
        cv = compact_deep_keep_false(v)
        next if drop_value?(cv)
        h[k] = cv
      end
    when Array
      arr = obj.map { |v| compact_deep_keep_false(v) }.reject { |v| drop_value?(v) }
      arr
    else
      obj
    end
  end

  def drop_value?(v)
    return false if v == false
    return true  if v.nil?
    return true  if v.is_a?(String) && v.strip.empty?
    return true  if v.is_a?(Array) && v.empty?
    return true  if v.is_a?(Hash) && v.empty?
    false
  end

  def whitelist_with_custom_fields(payload, allowed_fields)
    payload.select do |k, _|
      allowed_fields.include?(k) || k.to_s.match?(CUSTOM_FIELD_KEY_REGEX)
    end
  end

  def coerce_int!(hash, keys)
    keys.each do |k|
      next unless hash.key?(k)
      hash[k] = normalize_int(hash[k]) if hash[k].present?
    end
  end

  def normalize_int(v)
    return v.first.to_i if v.is_a?(Array)
    v.to_i
  end

  def normalize_int_array(v)
    arr =
      case v
      when Array
        v
      when String
        v.split(/[,\s]+/)
      else
        Array(v)
      end

    arr.map { |x| x.is_a?(Array) ? x.first : x }
       .compact
       .map(&:to_s)
       .map(&:strip)
       .reject(&:empty?)
       .map(&:to_i)
  end

  def coerce_bool!(hash, keys)
    caster = ActiveModel::Type::Boolean.new
    keys.each do |k|
      next unless hash.key?(k)
      hash[k] = caster.cast(hash[k])
    end
  end

  def normalize_date_yyyy_mm_dd!(hash, key)
    return unless hash[key].present?

    value = hash[key].to_s
    # Accept datetime and reduce to date
    begin
      date = Date.parse(value)
      hash[key] = date.strftime("%Y-%m-%d")
    rescue ArgumentError
      # invalid date => drop to avoid 400
      hash.delete(key)
    end
  end

  def normalize_hh_mm!(hash, key)
    return unless hash[key].present?

    v = hash[key].to_s.strip
    # Accept "HH:MM" only, otherwise drop (safer than 400)
    if v.match?(/\A\d{2}:\d{2}\z/)
      hash[key] = v
    else
      hash.delete(key)
    end
  end
end
