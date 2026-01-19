namespace :evolution do
  desc 'Setup RabbitMQ Topology based on Step 237 JSON'
  task setup_rabbitmq: :environment do
    require 'bunny'

    uri = ENV.fetch('RABBITMQ_URI', nil)
    puts "Connecting to #{uri}..."

    conn = Bunny.new(uri)
    conn.start
    ch = conn.create_channel

    puts 'Declaring Exchanges...'
    main_ex  = ch.topic('evolution_exchange', durable: true)
    retry_ex = ch.direct('evolution_retry', durable: true)
    dlx_ex   = ch.direct('evolution_dlx', durable: true)

    puts 'Declaring Queues...'
    # 1. Main Queue
    main_q = ch.queue('starchats_evolution_inbound', durable: true, arguments: {
                        'x-queue-type' => 'classic',
                        'x-dead-letter-exchange' => 'evolution_retry',
                        'x-dead-letter-routing-key' => 'retry'
                      })

    # 2. Main Queue V2 (from JSON)
    main_v2 = ch.queue('starchats_evolution_inbound_v2', durable: true, arguments: {
                         'x-queue-type' => 'classic',
                         'x-dead-letter-exchange' => 'evolution_retry',
                         'x-dead-letter-routing-key' => 'retry'
                       })

    # 3. Retry Queue (Delay 30s)
    retry_q = ch.queue('starchats_evolution_retry_30s', durable: true, arguments: {
                         'x-queue-type' => 'classic',
                         'x-message-ttl' => 30_000,
                         'x-dead-letter-exchange' => 'evolution_exchange',
                         'x-dead-letter-routing-key' => 'retry'
                       })

    # 4. DLQ (Dead Letter Queue)
    dlq_q = ch.queue('starchats_evolution_dlq', durable: true, arguments: {
                       'x-queue-type' => 'classic'
                     })

    puts 'Creating Bindings...'
    # Bind Main -> Exchange #
    main_q.bind(main_ex, routing_key: '#')
    main_v2.bind(main_ex, routing_key: '#')

    # Bind Retry Queue -> Retry Exchange (key: retry)
    retry_q.bind(retry_ex, routing_key: 'retry')

    # Bind DLQ -> DLX (key: dlq)
    dlq_q.bind(dlx_ex, routing_key: 'dlq')

    puts '✅ Topology Setup Completed Successfully!'
    conn.close
  rescue StandardError => e
    puts "❌ Setup Error: #{e.message}"
    puts e.backtrace.first(5)
  end
end
