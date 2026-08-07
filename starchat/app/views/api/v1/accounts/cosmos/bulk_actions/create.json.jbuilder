json.array! @responses do |response|
  json.partial! 'api/v1/models/cosmos/assistant_response', formats: [:json], resource: response
end
