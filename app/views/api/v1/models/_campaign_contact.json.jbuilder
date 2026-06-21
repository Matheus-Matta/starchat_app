json.id resource.id
json.status resource.status
json.sent_at resource.sent_at
json.error_message resource.error_message
json.created_at resource.created_at

json.contact do
  if resource.contact.present?
    json.id resource.contact.id
    json.name resource.contact.name
    json.email resource.contact.email
    json.phone_number resource.contact.phone_number
    json.thumbnail resource.contact.avatar_url
  end
end
