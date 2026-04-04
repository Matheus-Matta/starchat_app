json.additional_attributes resource.additional_attributes
json.availability_status resource.availability_status
json.email resource.email
json.id resource.id
json.name resource.name
json.phone_number resource.phone_number
json.blocked resource.blocked
json.identifier resource.identifier
json.thumbnail resource.avatar_url
json.custom_attributes resource.custom_attributes
json.responsible_agent_ids resource.responsible_agent_ids
json.responsible_agents resource.responsible_agents.map { |agent| { id: agent.id, name: agent.name, email: agent.email } }
json.last_activity_at resource.last_activity_at.to_i if resource[:last_activity_at].present?
json.created_at resource.created_at.to_i if resource[:created_at].present?
# we only want to output contact inbox when its /contacts endpoints
if defined?(with_contact_inboxes) && with_contact_inboxes.present?
  json.contact_inboxes do
    contact_inboxes = resource.contact_inboxes
    # Se a conta exige vínculo real, mostramos apenas inboxes que já possuem conversas
    contact_inboxes = contact_inboxes.joins(:conversations).distinct if resource.account.require_contact_inbox_messaging

    json.array! contact_inboxes do |contact_inbox|
      json.partial! 'api/v1/models/contact_inbox', formats: [:json], resource: contact_inbox
    end
  end
end
