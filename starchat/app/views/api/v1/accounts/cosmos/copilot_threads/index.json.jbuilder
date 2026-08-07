json.payload do
  json.array! @copilot_threads do |thread|
    json.partial! 'api/v1/models/cosmos/copilot_thread', resource: thread
  end
end
