class Ycloud::MessageReactionService
  pattr_initialize [:channel!, :payload!]

  def perform
    reaction = payload['reaction']
    return :ignored if reaction.blank?

    parent = find_parent(reaction['message_id'])
    return :parent_not_found if parent.blank?
    return remove_reaction(parent) if reaction['emoji'].blank?
    return :duplicate if parent.conversation.messages.exists?(source_id: source_id)

    message = parent.conversation.messages.build(
      account_id: parent.account_id,
      inbox_id: parent.inbox_id,
      sender: parent.conversation.contact,
      message_type: :incoming,
      content_type: :text,
      content: reaction['emoji'],
      source_id: source_id,
      additional_attributes: {
        'ycloud_reaction' => true,
        'ycloud_reaction_sender' => payload['from']
      }.compact
    )
    message.in_reply_to = parent.id
    message.save!
    :created
  end

  private

  def find_parent(external_id)
    channel.inbox.messages.find_by(source_id: external_id) ||
      channel.inbox.messages.where(
        'additional_attributes @> ?',
        { ycloud_wamid_values: [external_id] }.to_json
      ).first
  end

  def source_id
    payload['id'].presence || payload['wamid']
  end

  def remove_reaction(parent)
    reaction_message = parent.conversation.messages.find_by(source_id: source_id)
    reaction_message ||= reaction_scope(parent).order(created_at: :desc).first
    reaction_message&.destroy!
    :removed
  end

  def reaction_scope(parent)
    scope = parent.conversation.messages.where(in_reply_to: parent.id, message_type: :incoming)
                  .where("additional_attributes ->> 'ycloud_reaction' = ?", 'true')
    return scope if payload['from'].blank?

    scope.where("additional_attributes ->> 'ycloud_reaction_sender' = ?", payload['from'])
  end
end
