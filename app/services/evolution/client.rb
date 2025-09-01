# frozen_string_literal: true

require 'http'
require 'json'

class Evolution::Client
  def initialize(base_url:, api_key:)
    @base = base_url.to_s.chomp('/')
    bearer = api_key.to_s.start_with?('Bearer ') ? api_key : "Bearer #{api_key}"
    @headers = {
      'Content-Type'  => 'application/json',
      'Authorization' => bearer,
      'apikey'        => api_key
    }
  end
  # Instancia
  def create_instance(payload)   = post('/instance/create', payload)
  def connect_qr(instance)       = get("/instance/connect/#{instance}")
  def delete_instance(instance)  = delete("/instance/delete/#{instance}")
  def restart_instance(instance) = put("/instance/restart/#{instance}")
  def logout_instance(instance)  = delete("/instance/logout/#{instance}")

  # Webhook
  def set_webhook(instance, url)
    body = { instanceName: instance, url: url, base64: true }
    post('/webhook/instance', body)
  end

  # Mensagens
  def send_text(instance, number:, text:, **opts)
    # opts: delay:, linkPreview:, mentionsEveryOne:, mentioned:, quoted: ...
    payload = { number: number, text: text }.merge(opts).compact
    post("/message/sendText/#{instance}", payload)
  end

  def send_media(instance, number:, mediatype:, media:, mimetype: nil, caption: nil, **opts)
    payload = {
      number: number,
      mediatype: mediatype, # "image" | "video" | "document" | etc.
      mimetype: mimetype,
      caption: caption,
      media: media
    }.merge(opts).compact
    post("/message/sendMedia/#{instance}", payload)
  end

  def send_whatsapp_audio(instance, number:, audio:, **opts)
    payload = { number: number, audio: audio }.merge(opts).compact
    post("/message/sendWhatsAppAudio/#{instance}", payload)
  end

  def update_message(instance, number:, text:, key:)
    body = { number:, text:, key: key }.compact
    post("/chat/updateMessage/#{instance}", body)
  end

  def delete_message_for_everyone(instance, id:, remoteJid:, fromMe:, participant: nil)
    body = { id:, remoteJid:, fromMe:, participant: participant }.compact
    delete("/chat/deleteMessageForEveryone/#{instance}", body)
  end

  private

  def parse_body(resp)
    body = resp.body.to_s
    JSON.parse(body)
  rescue JSON::ParserError
    body
  end

  def http = HTTP.headers(@headers)

  def get(path)                   = parse_body(http.get(@base + path))
  def post(path, payload = nil)   = parse_body(payload ? http.post(@base + path, json: payload) : http.post(@base + path))
  def put(path, payload = nil)    = parse_body(payload ? http.put(@base + path,  json: payload) : http.put(@base + path))
  def delete(path, payload = nil) = parse_body(payload ? http.delete(@base + path, json: payload) : http.delete(@base + path))
end
