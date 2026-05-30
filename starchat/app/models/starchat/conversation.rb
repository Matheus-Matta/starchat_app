module Starchat::Conversation
  def list_of_keys
    super + %w[sla_policy_id]
  end

  def with_cosmos_activity_context(reason:, reason_type:)
    previous_reason = cosmos_activity_reason
    previous_reason_type = cosmos_activity_reason_type

    self.cosmos_activity_reason = reason
    self.cosmos_activity_reason_type = reason_type
    yield
  ensure
    self.cosmos_activity_reason = previous_reason
    self.cosmos_activity_reason_type = previous_reason_type
  end

  # Include select additional_attributes keys (call related) for update events
  def allowed_keys?
    return true if super

    attrs_change = previous_changes['additional_attributes']
    return false unless attrs_change.is_a?(Array) && attrs_change[1].is_a?(Hash)

    changed_attr_keys = attrs_change[1].keys
    changed_attr_keys.intersect?(%w[call_status])
  end

  private

  def dispatch_cosmos_inference_event(event_name)
    dispatcher_dispatch(event_name)
  end
end
