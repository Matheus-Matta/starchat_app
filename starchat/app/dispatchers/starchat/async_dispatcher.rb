module Starchat::AsyncDispatcher
  def listeners
    super + [
      CosmosListener.instance
    ]
  end
end
