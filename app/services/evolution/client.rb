# app/services/evolution/client.rb
# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'
require 'cgi'

module Evolution
  class Client
    class Error < StandardError; end

    attr_reader :base_url, :api_key, :default_headers, :open_timeout, :read_timeout

    DEFAULT_TIMEOUTS = {
      open:  Integer(ENV.fetch("EVOLUTION_HTTP_OPEN_TIMEOUT", 10)),  
      read:  Integer(ENV.fetch("EVOLUTION_HTTP_READ_TIMEOUT", 60)),   
      write: Integer(ENV.fetch("EVOLUTION_HTTP_WRITE_TIMEOUT", 30))  
    }.freeze

    def initialize(base_url:, api_key:, open_timeout: 5, read_timeout: 15)
      @base_url = base_url.to_s.sub(%r{/\z}, '')
      @api_key  = api_key.to_s
      @open_timeout = open_timeout
      @read_timeout = read_timeout

      @default_headers = {
        'Content-Type' => 'application/json',
        'apikey'       => @api_key
      }.freeze
    end

    # ========= Instances =========

    # POST /instance/create
    def create_instance(payload)
      post('/instance/create', payload)
    end

    # GET /instance/connect/:instance
    def connect_qr(instance_name)
      get("/instance/connect/#{escape(instance_name)}")
    end

    # PUT /instance/restart/:instance
    def restart_instance(instance_name)
      put("/instance/restart/#{escape(instance_name)}")
    end

    # DELETE /instance/logout/:instance
    def logout_instance(instance_name)
      delete("/instance/logout/#{escape(instance_name)}")
    end

    # DELETE /instance/delete/:instance
    # (fallback usado no controller#disconnect)
    def delete_instance(instance_name)
      delete("/instance/delete/#{escape(instance_name)}")
    end

    # ========= Webhook =========

    # POST /webhook/instance
    # body: { instanceName:, url: }
    def set_webhook(instance_name, url)
      post('/webhook/instance', { instanceName: instance_name, url: url })
    end

    # ========= Messages =========

    # POST /message/sendText/:instance
    # body: { number:, text: }

    # POST /message/sendText/:instance
    # body: { number:, text:, quoted?, delay?, mentionsEveryOne?, mentioned? }
    def send_text(instance, number:, text:, quoted: nil, delay: 0)
      body = {
        number: normalize_number(number),
        text:   text
      }
      body[:quoted] = quoted if quoted.present?
      body[:delay]  = delay.to_i if delay.to_i.positive?

      post("/message/sendText/#{escape(instance)}", body)
    end

    def send_media(instance, number:, mediatype:, media:, mimetype:, caption: nil, file_name: nil, quoted: nil, delay: 0)
      raise Error, "invalid media URL" unless media.is_a?(String) && media.start_with?("http")

      body = {
        number:    normalize_number(number),
        mediatype: mediatype,
        media:     media
      }
      body[:mimetype] = mimetype if mimetype.present?
      body[:caption]  = caption  if caption.present?
      body[:fileName] = file_name if file_name.present?
      body[:quoted]   = quoted   if quoted.present?
      body[:delay]    = delay.to_i if delay.to_i.positive?

      media_read_timeout = Integer(ENV.fetch("EVOLUTION_HTTP_MEDIA_READ_TIMEOUT", 180))
      post("/message/sendMedia/#{escape(instance)}", body,
           timeouts: { open: DEFAULT_TIMEOUTS[:open], write: DEFAULT_TIMEOUTS[:write], read: media_read_timeout })
    end

    def send_whatsapp_audio(instance, number:, audio:, quoted: nil, delay: 0)
      body = {
        number: normalize_number(number),
        audio:  audio
      }
      body[:quoted] = quoted if quoted.present?
      body[:delay]  = delay.to_i if delay.to_i.positive?

      media_read_timeout = Integer(ENV.fetch("EVOLUTION_HTTP_MEDIA_READ_TIMEOUT", 180))
      post("/message/sendWhatsAppAudio/#{escape(instance)}", body,
           timeouts: { open: DEFAULT_TIMEOUTS[:open], write: DEFAULT_TIMEOUTS[:write], read: media_read_timeout })
    end

    private

    def stringy?(v) = v.is_a?(String) && !v.empty?

    def get(path)
      request(:get, path)
    end

    def post(path, body, timeouts: {}, idempotency_key: nil, retries: 2)
      t   = DEFAULT_TIMEOUTS.merge(timeouts || {})
      url = URI.join(@base_url + "/", path.sub(%r{^/}, ""))

      attempt = 0
      begin
        http = Net::HTTP.new(url.host, url.port)
        http.use_ssl = (url.scheme == "https")
        http.open_timeout  = t[:open]
        http.read_timeout  = t[:read]
        http.write_timeout = t[:write] if http.respond_to?(:write_timeout)
        http.keep_alive_timeout = 20   if http.respond_to?(:keep_alive_timeout)

        req = Net::HTTP::Post.new(url)
        req["apikey"]        = @api_key
        req["Content-Type"]  = "application/json"
        req["Connection"]    = "keep-alive"
        req["Idempotency-Key"] = idempotency_key if idempotency_key # <- evita duplicar no servidor (se ele suportar)
        req.body = JSON.generate(body)

        res = http.request(req)
        unless res.is_a?(Net::HTTPSuccess)
          raise Error, (parse_err(res) || "#{res.code} #{res.message}")
        end
        return parse_json(res.body)

      rescue Net::OpenTimeout, Net::ReadTimeout, EOFError, Errno::ECONNRESET, Errno::ETIMEDOUT => e
        attempt += 1
        raise Error, e.message if attempt > retries
        sleep(0.5 * (2 ** (attempt - 1)) + rand * 0.1)
        retry
      end
    end

    def put(path, body = nil)
      request(:put, path, body)
    end

    def delete(path, body = nil)
      request(:delete, path, body)
    end

    def request(method, path, body = nil)
      uri = URI.parse("#{base_url}#{path}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.open_timeout = open_timeout
      http.read_timeout = read_timeout

      req = build_request(method, uri, body)

      res = http.request(req)
      parse_response!(res)
    rescue JSON::ParserError => e
      raise Error, "Invalid JSON response: #{e.message}"
    rescue StandardError => e
      raise Error, e.message
    end

    def build_request(method, uri, body)
      klass = case method
              when :get then Net::HTTP::Get
              when :post then Net::HTTP::Post
              when :put then Net::HTTP::Put
              when :delete then Net::HTTP::Delete
              else
                raise ArgumentError, "Unsupported method: #{method}"
              end
      req = klass.new(uri)
      default_headers.each { |k, v| req[k] = v }
      req.body = body.to_json if body
      req
    end

    def parse_response!(res)
      code = res.code.to_i
      payload = res.body.to_s
      json = payload.empty? ? {} : JSON.parse(payload)

      return json if code.between?(200, 299)

      msg = json['message'] || json['error'] || "HTTP #{code}"
      raise Error, msg
    end

    def parse_json(str)
      str && !str.empty? ? JSON.parse(str) : {}
    rescue JSON::ParserError
      {}
    end

    def parse_err(res)
      body = parse_json(res.body)
      body["message"] || body.dig("response", "message")
    rescue
      nil
    end

    def escape(v)
      CGI.escape(v.to_s)
    end

    def normalize_number(n)
      s = n.to_s
      return s unless s.end_with?("@s.whatsapp.net")
      s.split("@").first
    end
  end
end
