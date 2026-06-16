json.array! @conversation_flows do |conversation_flow|
  json.partial! 'conversation_flow', conversation_flow: conversation_flow
end
