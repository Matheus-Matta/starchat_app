namespace :evolution do
  desc "Start the RabbitMQ Consumer for Evolution events"
  task rabbitmq: :environment do
    Evolution::RabbitmqConsumer.new.start
  end
end
