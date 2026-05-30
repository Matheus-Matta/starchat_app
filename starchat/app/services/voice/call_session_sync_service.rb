class Voice::CallSessionSyncService
  pattr_initialize [:conversation!, :call_sid!, :message_call_sid!, { leg: {} }]

  def perform
    update_conversation_leg
    conversation
  end

  private

  def update_conversation_leg
    attrs = conversation.additional_attributes || {}
    leg_key = "leg_#{call_sid}"
    attrs[leg_key] = leg.merge(call_sid: call_sid)
    conversation.update!(additional_attributes: attrs)
  end
end
