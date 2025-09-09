# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

module Integrations
  module Typebot
    class Client
      DEFAULT_BASE = 'https://typebot.io/api'

      def initialize(api_token:, base_url: ENV.fetch('TYPEBOT_API_BASE', DEFAULT_BASE))
        @api_token = api_token
        @base_url  = base_url
      end

      def start_chat(public_id:, payload:)
        post("/v1/typebots/#{public_id}/startChat", payload)
      end

      def continue_chat(session_id:, payload:)
        post("/v1/sessions/#{session_id}/continueChat", payload)
      end

      private

      def post(path, body)
        uri = URI.join(@base_url, path)
        req = Net::HTTP::Post.new(uri)
        req['Authorization'] = "Bearer #{@api_token}"
        req['Content-Type']  = 'application/json'
        req.body = JSON.dump(body || {})

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == 'https'
        res  = http.request(req)

        raise "Typebot API #{res.code}: #{res.body}" unless res.is_a?(Net::HTTPSuccess)
        JSON.parse(res.body) rescue {}
      end
    end
  end
end
