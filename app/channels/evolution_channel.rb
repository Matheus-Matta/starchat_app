# app/channels/evolution_channel.rb
class EvolutionChannel < ApplicationCable::Channel
  def subscribed
    reject unless params[:inbox_id].present?
    stream_from "evolution:inbox:#{params[:inbox_id]}"
  end
end
