module Baileys
  class EventHandler
    def self.call(data)
      event = data['event'] || data['type']
      payload = data['payload'] || data
      
      # Normalizar payload se necessário
      payload = payload.with_indifferent_access if payload.is_a?(Hash)

      case event
      when 'qrcode_updated'
        handle_qrcode(payload)
      when 'connection_update'
        handle_connection_update(payload)
      when 'message_upsert'
        handle_message(payload)
      else
        Rails.logger.warn "[Baileys] Unknown event: #{event}"
      end
    end

    def self.handle_qrcode(payload)
      channel_id = payload[:channel_id]
      return unless channel_id
      
      channel = Channel::Baileys.find_back_id(channel_id) rescue Channel::Baileys.find_by(id: channel_id)
      return unless channel
      
      # Salva QR no banco (Rails controlando dados)
      channel.update!(qrcode: payload[:qrcode_base64], state: 'qrcode')
      
      inbox = Inbox.find_by(channel: channel)
      return unless inbox
      
      # Broadcast para frontend
      Rails.logger.info "[Baileys] Broadcasting qrcode_updated for inbox #{inbox.id}"
      ActionCable.server.broadcast("account_#{inbox.account_id}", {
        event: 'baileys.qrcode_updated',
        data: {
          inbox_id: inbox.id,
          account_id: inbox.account_id,
          qrcode_base64: payload[:qrcode_base64],
          pairing_code: payload[:pairing_code]
        }
      })
    end

    def self.handle_connection_update(payload)
      channel_id = payload[:channel_id]
      state = payload[:state]
      return unless channel_id && state
      
      mapped_state = case state
                     when 'open' then 'connected'
                     when 'close' then 'disconnected'
                     else state
                     end
      
      channel = Channel::Baileys.find_by(id: channel_id)
      return unless channel
      
      Rails.logger.info "[Baileys] Channel #{channel.id} state: #{state} -> #{mapped_state}"
      
      if Channel::Baileys.states.keys.include?(mapped_state)
        channel.update!(state: mapped_state)
      else
        Rails.logger.warn "[Baileys] Unknown state for channel #{channel.id}: #{state}"
        return
      end
      
      inbox = Inbox.find_by(channel: channel)
      return unless inbox
      
      ActionCable.server.broadcast("account_#{inbox.account_id}", {
        event: 'baileys.connection_update',
        data: {
          inbox_id: inbox.id,
          account_id: inbox.account_id,
          state: mapped_state
        }
      })
    end

    def self.handle_message(payload)
      channel_id = payload[:channel_id]
      channel = Channel::Baileys.find_by(id: channel_id)
      return unless channel
      
      inbox = Inbox.find_by(channel: channel)
      return unless inbox
      
      Baileys::IncomingMessageService.new(inbox: inbox, payload: payload).perform
    end
  end
end
