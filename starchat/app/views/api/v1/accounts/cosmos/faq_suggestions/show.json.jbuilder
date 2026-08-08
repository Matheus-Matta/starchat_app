json.partial! 'api/v1/models/cosmos/faq_suggestion', formats: [:json], resource: @suggestion
json.observations do
  json.array! @observations do |observation|
    json.partial! 'api/v1/models/cosmos/faq_observation', formats: [:json], resource: observation
  end
end
