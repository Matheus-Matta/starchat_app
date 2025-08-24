module Starchat::AsyncDispatcher
  def listeners
    super + [
      CaptainListener.instance
    ]
  end
end
