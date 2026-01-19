require 'bunny'

module Evolution
  class RabbitmqConsumer
    MAX_RETRIES = 5
    PREFETCH_COUNT = 10 # Aumentado para melhor throughput

    def start
      @logger = Logger.new(STDOUT)
      @logger.info '[EvolutionRabbit] Initializing Consumer Service...'

      conn_uri = ENV.fetch('RABBITMQ_URI', nil)

      # 3.4 Configurações de Conexão Robustas
      conn = Bunny.new(conn_uri,
                       automatically_recover: true,
                       heartbeat: 10,
                       network_recovery_interval: 5,
                       recover_from_connection_close: true,
                       logger: @logger)

      conn.start
      @logger.info '[EvolutionRabbit] Connected to RabbitMQ!'

      ch = conn.create_channel
      ch.prefetch(PREFETCH_COUNT) # 3.3 Prefetch otimizado

      exchange_name = ENV.fetch('RABBITMQ_EXCHANGE_NAME', 'evolution_exchange')

      x = ch.topic(exchange_name, durable: true)

      queue_name = ENV.fetch('RABBITMQ_MAIN_QUEUE', 'starchats_evolution_inbound')

      q = ch.queue(queue_name, durable: true, arguments: {
                     'x-queue-type' => 'classic',
                     'x-dead-letter-exchange' => 'evolution_retry',
                     'x-dead-letter-routing-key' => 'retry'
                   })

      q.bind(x, routing_key: '#')

      @dlx_exchange = ch.direct(ENV.fetch('RABBITMQ_DLX_EXCHANGE', 'evolution_dlx'), durable: true)

      @logger.info "[EvolutionRabbit] Waiting for messages on '#{q.name}' (Prefetch: #{PREFETCH_COUNT})..."

      # 3.5 block: false com loop manual para não travar recovery
      q.subscribe(manual_ack: true, block: false) do |delivery_info, properties, body|
        handle_message(ch, delivery_info, properties, body)
      end

      # Manter processo vivo
      begin
        loop { sleep 5 }
      rescue Interrupt
        @logger.info '[EvolutionRabbit] Shutting down...'
        ch.close
        conn.close
      end
    end

    private

    def handle_message(ch, delivery_info, properties, body)
      @logger.info "[EvolutionRabbit] 📥 Msg Received [Tag: #{delivery_info.delivery_tag}] | Size: #{body.bytesize} bytes"
      begin
        # 3.6 Validação de Payload
        payload = JSON.parse(body)

        # Processamento principal
        process_payload(payload)

        # 3.1 Sucesso -> Ack
        ch.ack(delivery_info.delivery_tag)

      rescue JSON::ParserError => e
        @logger.info "[EvolutionRabbit] ❌ Invalid JSON -> DLQ: #{e.message}"
        publish_to_dlq(body, properties, "invalid_json: #{e.message}")
        ch.ack(delivery_info.delivery_tag)

      rescue StandardError => e
        # 3.2 Retry com Contador (x-death)
        handle_retry(ch, delivery_info, properties, e, body)
      end
    end

    def handle_retry(ch, delivery_info, properties, error, body)
      retry_count = get_retry_count(properties)

      if retry_count >= MAX_RETRIES
        @logger.info "[EvolutionRabbit] 💀 FATAL: Max retries reached (#{retry_count}). Sending to DLQ."
        @logger.info "[EvolutionRabbit] 🛑 Error Details: #{error.class} - #{error.message}"
        @logger.info "[EvolutionRabbit] 🛑 Backtrace: #{error.backtrace&.first(3)&.join(' | ')}"

        publish_to_dlq(body, properties, "max_retries: #{error.message}")
        ch.ack(delivery_info.delivery_tag)
      else
        @logger.info "[EvolutionRabbit] ⚠️ Transient Error (Retry #{retry_count + 1}/#{MAX_RETRIES}): #{error.class} - #{error.message}"
        ch.nack(delivery_info.delivery_tag, false, false) # vai pro retry via DLX
      end
    end

    def get_retry_count(properties)
      headers = properties[:headers] || {}
      deaths = headers['x-death'] || []
      queue_name = ENV.fetch('RABBITMQ_MAIN_QUEUE', 'starchats_evolution_inbound')

      deaths
        .select { |d| d['queue'] == queue_name }
        .sum { |d| d['count'].to_i }
    end

    def publish_to_dlq(body, properties, error_msg)
      headers = (properties[:headers] || {}).merge(
        'x-error' => error_msg,
        'x-failed-at' => Time.now.utc.iso8601
      )

      @dlx_exchange.publish(
        body,
        routing_key: ENV.fetch('RABBITMQ_DLX_ROUTING_KEY', 'dlq'),
        persistent: true,
        content_type: properties[:content_type] || 'application/json',
        headers: headers
      )
    end

    def process_payload(raw)
      return if raw.blank?

      evt = (raw['event'] || '').to_s.tr('.', '_').downcase.strip
      instance_name = raw['instance']

      return if instance_name.blank?

      # Log de processamento do evento específico
      @logger.info "[EvolutionRabbit] ⚙️ Processing Event: #{evt} | Instance: #{instance_name}"

      # 3.7 Cache por Instance
      mapping = resolve_instance_cached(instance_name)

      unless mapping
        @logger.info "[EvolutionRabbit] ⚠️ Ignored Event: Instance '#{instance_name}' not found or unmapped in Starchats."
        return
      end

      data = raw['data']

      case evt
      when 'qrcode_updated'
        handle_qrcode(mapping, data)
      when 'connection_update'
        handle_connection(instance_name, mapping, data)
      when 'messages_upsert', 'messages_update',
           'contacts_update', 'contacts_upsert',
           'chats_update', 'chats_upsert'
        enqueue_job(mapping, evt, data)
      when 'send_message'
        @logger.info '[EvolutionRabbit] 📤 Message sent confirmed (SEND_MESSAGE)'
      end
    end

    # 3.7 Caching Simples
    def resolve_instance_cached(instance_name)
      # Cache ID: evo_map_<instance_name>
      # Expiração: 5 minutos
      Rails.cache.fetch("evo_map_#{instance_name}", expires_in: 5.minutes) do
        channel = Channel::Evolution.find_by(instance_name: instance_name)
        return nil unless channel

        inbox = Inbox.find_by(channel_id: channel.id)
        return nil unless inbox

        # Retorna hash leve para evitar problemas com objetos ActiveRecord em cache
        {
          channel_id: channel.id,
          inbox_id: inbox.id,
          account_id: inbox.account_id
        }
      end
    end

    def handle_qrcode(mapping, data)
      q = (data.is_a?(Hash) ? (data['qrcode'] || {}) : {}).with_indifferent_access
      broadcast(mapping, 'evolution.qrcode_updated', {
        qrcode_base64: q[:base64],
        pairing_code: q[:pairingCode]
      }.compact)
    end

    def handle_connection(_instance_name, mapping, data)
      state = data.is_a?(Hash) ? data['state'].to_s : nil
      return unless state.present?

      # Atualiza DB apenas se conectar/desconectar (evita hits desnecessários)
      Channel::Evolution.where(id: mapping[:channel_id]).update_all(state: state, state_updated_at: Time.current)
      broadcast(mapping, 'evolution.connection_update', { state: state })
    end

    def broadcast(mapping, event_name, payload)
      ActionCable.server.broadcast(
        "account_#{mapping[:account_id]}",
        {
          event: event_name,
          data: payload.merge(account_id: mapping[:account_id], inbox_id: mapping[:inbox_id])
        }
      )
    end

    def enqueue_job(mapping, evt, data)
      payload_data = data
      payload_data = [payload_data] if %w[messages_upsert messages_update contacts_update chats_update].include?(evt) && payload_data.is_a?(Hash)

      Webhooks::EvolutionEventsJob.perform_later(inbox_id: mapping[:inbox_id], event: evt, data: payload_data || [])
      @logger.info "[EvolutionRabbit] 🚀 Dispatch Job: Webhooks::EvolutionEventsJob | Inbox: #{mapping[:inbox_id]} | Event: #{evt}"
    end
  end
end
