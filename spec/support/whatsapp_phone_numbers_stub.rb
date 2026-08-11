# Whatsapp::WebhookSetupService now resolves the WABA's phone number id before
# subscribing (upstream moved from subscribe_waba_webhook to
# subscribe_phone_number_webhook in v4.16.0). Any spec that creates or migrates a
# WhatsApp channel therefore reaches out to the Graph API and dies on
# WebMock::NetConnectNotAllowedError before asserting anything.
#
# Stubbing it here keeps the network boundary closed by default. Specs that assert
# on this call register their own stub inside the example, and WebMock gives
# precedence to the most recently registered one.
RSpec.configure do |config|
  config.before do
    stub_request(:get, %r{graph\.facebook\.com/.+/phone_numbers}).to_return(
      status: 200,
      body: { data: [{ id: '123456789' }] }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
  end
end
