json.data do
  json.meta do
    json.count @campaign_contacts.total_count
    json.current_page @campaign_contacts.current_page
    json.total_pages @campaign_contacts.total_pages
  end

  json.payload do
    json.array! @campaign_contacts do |campaign_contact|
      json.partial! 'api/v1/models/campaign_contact', formats: [:json], resource: campaign_contact
    end
  end
end
