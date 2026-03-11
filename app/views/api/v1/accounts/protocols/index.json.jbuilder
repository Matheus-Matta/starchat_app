json.data do
  json.array! @protocols, partial: 'api/v1/accounts/protocols/protocol', as: :protocol
end
json.meta do
  json.current_page @protocols.current_page
  json.total_pages  @protocols.total_pages
  json.total_count  @protocols.total_count
end
