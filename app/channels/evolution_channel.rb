# app/channels/evolution_channel.rb
class EvolutionChannel < ApplicationCable::Channel
  def subscribed
    reject if params[:inbox_id].blank?
    stream_from "evolution:inbox:#{params[:inbox_id]}"
  end
end
