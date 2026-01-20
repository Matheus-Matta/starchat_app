# On successful processing, responds with HTTP 200 OK.
class Starchat::Webhooks::StripeController < ActionController::API
  def process_payload
    request.body.read
    request.headers['Stripe-Signature']
    begin
    rescue JSON::ParserError, Stripe::SignatureVerificationError
      head :bad_request
      return
    end
    head :ok
  end
end
