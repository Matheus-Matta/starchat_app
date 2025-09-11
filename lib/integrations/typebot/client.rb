# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

module Integrations
    module Typebot
        class Client

            def initialize(api_token:, base_url: ENV.fetch('TYPEBOT_API_BASE', DEFAULT_BASE))
                @api_token = api_token
                @base_url  = base_url
            end

            def start_chat(public_id:, payload:)
                puts "[Typebot::Client] Starting chat with public_id: #{public_id}, payload: #{payload.inspect}"
                post("api/v1/typebots/#{public_id}/startChat", payload)
            end

            def continue_chat(session_id:, payload:)
                puts "[Typebot::Client] Continuing chat with session_id: #{session_id}, payload: #{payload.inspect}"
                post("api/v1/sessions/#{session_id}/continueChat", payload)
            end

            private

            def post(path, body)
                puts "[Typebot::Client] POST #{body}"
                uri = URI.join(@base_url, path)
                req = Net::HTTP::Post.new(uri)
                req['Authorization'] = "Bearer #{@api_token}"
                req['Content-Type']  = 'application/json'
                req.body = JSON.dump(body || {})

                http = Net::HTTP.new(uri.host, uri.port)
                http.use_ssl = uri.scheme == 'https'
                http.open_timeout = 3
                http.read_timeout = 8
                res  = http.request(req)

                raise "Typebot API #{res.code}: #{res.body}" unless res.is_a?(Net::HTTPSuccess)
                JSON.parse(res.body) rescue {}
            end
        end
    end
end
