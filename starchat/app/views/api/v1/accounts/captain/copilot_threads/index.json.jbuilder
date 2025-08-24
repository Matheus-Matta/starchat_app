json.payload do
  json.array! @copilot_threads do |thread|
    json.partial! 'api/v1/models/cosmo/copilot_thread', resource: thread
  end
end
