# Creating an enabled OpenAI integration hook validates the API key, and that
# validation performs a live `GET <endpoint>/v1/models`. Any spec that builds such
# a hook — directly or through a factory — would otherwise die on
# WebMock::NetConnectNotAllowedError before reaching what it actually asserts.
#
# Stubbing it here, rather than in each spec, keeps the network boundary closed by
# default. The endpoint is configurable (COSMOS_OPEN_AI_ENDPOINT), so the pattern
# matches any host. Specs that exercise the validator itself register their own
# stubs inside the example, and WebMock gives precedence to the most recently
# registered one.
RSpec.configure do |config|
  config.before do
    stub_request(:get, %r{/v1/models\z}).to_return(
      status: 200,
      body: { data: [] }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
  end
end
