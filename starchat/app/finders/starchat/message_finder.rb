module Starchat::MessageFinder
  def conversation_messages
    super.includes(call: [:contact, { inbox: :channel }])
  end
end
