json.id protocol.id
json.code protocol.code
json.seq protocol.seq
json.date protocol.date
json.status protocol.status
json.reason protocol.reason
json.description protocol.description
json.problem protocol.problem
json.closed_at protocol.closed_at
json.created_at protocol.created_at
json.updated_at protocol.updated_at
json.account_id protocol.account_id
json.protocol_policy_id protocol.protocol_policy_id
json.conversation_id protocol.conversation_id
json.conversations_count protocol.conversations.size

# Contato vinculado (resumo)
if protocol.contact
  json.contact do
    json.id protocol.contact.id
    json.name protocol.contact.name
    json.email protocol.contact.email
    json.phone_number protocol.contact.phone_number
  end
else
  json.contact nil
end

# Política de protocolo (resumo)
if protocol.protocol_policy
  json.protocol_policy do
    json.id protocol.protocol_policy.id
    json.name protocol.protocol_policy.name
    json.prefix protocol.protocol_policy.prefix
    json.scope protocol.protocol_policy.scope
  end
else
  json.protocol_policy nil
end

# Contagens
json.comments_count protocol.protocol_comments.size
