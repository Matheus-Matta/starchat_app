# app/services/evolution/send_message_service.rb
# frozen_string_literal: true

require 'uri'
require 'base64'

class Evolution::SendMessageService
  include Evolution::StatusUpdate

  MEDIA_ORDER = %i[image video audio document].freeze

  def initialize(message:, channel: nil, skip_attachments: false)
    @message      = message
    @conversation = message.conversation
    @inbox        = @conversation.inbox
    @channel      = channel || @inbox.channel
    @skip_attachments = skip_attachments
    @evolution_message_id = nil
  end

  def perform
    return unless evolution_channel?

    # Handle non-dispatchable messages (private or invalid type)
    unless dispatchable?
      mark_as_blocked!
      return
    end

    in_reply_to_val = @message.content_attributes&.dig('in_reply_to')
    Rails.logger.info("[Evolution::SendMessageService] STARTED msg=#{@message.id} content='#{@message.content}' in_reply_to=#{in_reply_to_val} atts=#{@message.content_attributes}")

    if already_dispatched? || @message.delivered? || @message.read?
      Rails.logger.info("[Evolution::SendMessageService] skip: message #{message.id} already dispatched (source_id=#{message.source_id.inspect}, status=#{message.status})")
      return
    end

    client   = build_client
    number   = recipient_waid
    instance = @channel.instance_name

    quote = safely_build_quoted_for(@message)

    @any_success = false

    Rails.logger.info("[Evolution::SendMessageService] perform msg=#{@message.id} content=#{@message.content.inspect} attachments=#{@message.attachments.count} quoted_id=#{quote&.dig(
      'key', 'id'
    )}")

    # Enviar texto primeiro, se houver
    if @message.content.present?
      begin
        # Use outgoing_content para incluir o link do CSAT quando aplicável
        text_content = @message.outgoing_content.to_s.strip
        sender_config = @inbox.sender_config || {}
        if sender_config['send_agent_name'] && @message.sender.is_a?(User)
          agent_name = @message.sender.try(:display_name).presence || @message.sender.name
          text_content = "*#{agent_name}:*\n#{text_content}" if agent_name.present?
        end

        resp = client.send_text(instance, number: number, text: text_content, quoted: quote)
        persist_message_id_from(resp)
        @any_success = true
      rescue StandardError => e
        record_send_error!(error: e, kind: :text, payload: { number: number, instance: instance })
        return unless @message.attachments.exists? # Se só tinha texto e falhou, para
      end
    end

    # Se tivermos ativado o BatchSendService externamente ou se quisermos usar o modo legado:
    # Por padrão, mantemos a lógica síncrona aqui SE este serviço for chamado diretamente.
    # Mas criamos o método público `send_single_attachment` para ser usado pelos jobs.

    # Enviar anexos (modo síncrono legado ou se chamado diretamente)
    unless @skip_attachments
      ordered_attachments.each_with_index do |att, index|
        send_single_attachment(att, index: index)
      end
    end

    if any_success?
      mark_dispatched!
      update_message_status!(message: @message, status: 'delivered', external_error: nil)
    end
  rescue Evolution::Client::Error => e
    Rails.logger.error "[Evolution::SendMessageService] API error: #{e.message}"
  rescue StandardError => e
    Rails.logger.error "[Evolution::SendMessageService] #{e.class}: #{e.message}"
  end

  # Novo método público para ser usado pelo SendAttachmentJob
  def send_single_attachment(att, index: 0)
    return unless evolution_channel?
    return if already_dispatched?

    # Se chamado via Job, @channel e @client precisam estar prontos
    client   = build_client
    number   = recipient_waid
    instance = @channel.instance_name
    quoted   = safely_build_quoted_for(@message)

    kind     = file_kind(att)
    mimetype = att.file.content_type
    fname    = att.file.filename.to_s
    filesize = att.file.byte_size

    # "Video no app geralmente fica em torno de 100MB"
    # Se for maior que 100MB, envia como documento (até 2GB)
    blob_to_use = att.file.blob

    # Tenta comprimir vídeo antes de enviar
    if kind == :video
      begin
        compressed = try_compress_video(att.file)
        if compressed
          blob_to_use = compressed
          filesize    = blob_to_use.byte_size # Atualiza tamanho para log
          Rails.logger.info "[Evolution] Using compressed video: #{filesize} bytes (Original: #{att.file.byte_size})"
        end
      rescue StandardError => e
        Rails.logger.error "[Evolution] Video compression failed: #{e.message}. Using original."
      end
    end

    # "Video no app geralmente fica em torno de 100MB"
    if kind == :video && filesize > 100.megabytes
      Rails.logger.info("[Evolution] Video too large (#{filesize} bytes), sending as document: #{fname}")
      kind = :document
    end

    # Delay / Jitter
    base_delay = (index + 1) * rand(1000..2000)

    begin
      if force_base64?
        send_attachment_base64(client, instance, number, kind, blob_to_use, mimetype, fname, quoted, delay: base_delay)
      else
        begin
          url = active_storage_url(blob_to_use, expires_in: media_url_ttl)
          send_attachment_url(client, instance, number, kind, url, mimetype, fname, quoted, delay: base_delay)
        rescue StandardError => e
          Rails.logger.warn("[Evolution] URL send failed for msg=#{@message.id}, falling back to Base64: #{e.message}")
          send_attachment_base64(client, instance, number, kind, blob_to_use, mimetype, fname, quoted, delay: base_delay)
        end
      end

      # Marca sucesso se pelo menos um passar
      @any_success = true

    rescue StandardError => e
      record_send_error!(error: e, kind: kind, payload: { number: number, instance: instance, url: begin
        url
      rescue StandardError
        nil
      end, mimetype: mimetype })
      raise e # Re-raise para o Job tentar retry se falhar
    end
  end

  private

  def any_success?
    @any_success
  end

  def send_attachment_url(client, instance, number, kind, url, mimetype, fname, quoted, delay: 0)
    if kind == :audio

      resp = client.send_whatsapp_audio(
        instance,
        number: number,
        audio: url,  # Evolution aceita URL aqui
        delay: delay,
        quoted: quoted
      )
    else
      mediatype = kind_to_mediatype(kind)
      opts = { mimetype: mimetype, quoted: quoted, delay: delay }
      opts[:file_name] = fname if mediatype == 'document'

      resp = client.send_media(
        instance,
        number: number,
        mediatype: mediatype,
        media: url, # URL
        **opts
      )

    end
    persist_message_id_from(resp)
  end

  def send_attachment_base64(client, instance, number, kind, blob, mimetype, fname, quoted, delay: 0)
    base64_data = encode_blob_base64(blob)

    if kind == :audio
      resp = client.send_whatsapp_audio(instance, number: number, audio: base64_data, delay: delay, quoted: quoted)
    else
      mediatype = kind_to_mediatype(kind)
      opts = { mimetype: mimetype, quoted: quoted, delay: delay }
      opts[:file_name] = fname if mediatype == 'document'

      resp = client.send_media(instance, number: number, mediatype: mediatype, media: base64_data, **opts)
    end
    persist_message_id_from(resp)
  end

  def kind_to_mediatype(kind)
    case kind
    when :image then 'image'
    when :video then 'video'
    else 'document'
    end
  end

  def force_base64?
    # Em development local com Docker, Evolution pode não acessar localhost.
    # Use EVOLUTION_FORCE_BASE64=true se necessário.
    ActiveRecord::Type::Boolean.new.cast(ENV.fetch('EVOLUTION_FORCE_BASE64', nil))
  end

  attr_reader :message

  def evolution_channel?
    @channel.is_a?(::Channel::Evolution)
  end

  def dispatchable?
    # Send outgoing and template messages (like CSAT) that are NOT private
    # Private messages (internal notes, system errors) should NEVER go to the client
    # Template messages include CSAT surveys and other system-generated messages that should be sent to contacts
    (@message.outgoing? || @message.template?) && !@message.private?
  end

  def already_dispatched?
    @message.source_id.present? || @message.additional_attributes.to_h['evolution_dispatched']
  end

  def build_client
    Evolution::Client.new(
      base_url: ENV.fetch('EVOLUTION_BASE_URL'),
      api_key: @channel.api_key.presence || ENV.fetch('AUTHENTICATION_API_KEY')
    )
  end

  def recipient_waid
    @conversation.contact_inbox.source_id
  end

  def ordered_attachments
    @message.attachments.to_a.sort_by { |att| MEDIA_ORDER.index(file_kind(att)) || 99 }
  end

  def file_kind(att)
    ct = att.file.content_type.to_s
    return :image if ct.start_with?('image/')
    return :video if ct.start_with?('video/')
    return :audio if ct.start_with?('audio/')

    :document
  end

  def active_storage_url(blob, expires_in: 15.minutes)
    if blob.respond_to?(:url) # Rails 7.1+
      blob.url(expires_in: expires_in, disposition: 'inline', filename: blob.filename)
    else
      blob.service_url(expires_in: expires_in, disposition: 'inline', filename: blob.filename)
    end
  end

  def media_url_ttl
    Integer(ENV.fetch('EVOLUTION_MEDIA_URL_TTL_SECONDS', 900))
  end

  def build_quoted_for(message)
    attrs = message.content_attributes.to_h

    external_id = attrs['in_reply_to_external_id'].presence

    parent = message.respond_to?(:in_reply_to) ? message.in_reply_to : nil
    parent = Message.find_by(id: parent) if parent.is_a?(Integer) || parent.is_a?(String)
    parent ||= Message.find_by(id: attrs['in_reply_to']) if attrs['in_reply_to'].present?

    if external_id.blank? && parent.present?
      parent_attrs = parent.respond_to?(:content_attributes) ? parent.content_attributes.to_h : {}
      external_id  = parent.source_id.presence || parent_attrs['external_id'].presence
    end

    return nil if external_id.blank?

    remote_jid =
      parent&.conversation&.contact_inbox&.source_id ||
      message.conversation.contact_inbox.source_id
    remote_jid = "#{remote_jid}@s.whatsapp.net" if remote_jid.present? && remote_jid.exclude?('@')

    from_me = parent.present? ? parent.outgoing? : false

    preview =
      attrs['quoted_preview'].presence ||
      (parent.content.to_s if parent.respond_to?(:content))

    if preview.present?
      preview = preview.gsub(/\R+/, ' ').strip
      preview = preview[0, 240] if preview.length > 240
    elsif parent&.attachments&.any?
      file_type = parent.attachments.first.file_type
      preview = "📷 #{file_type.capitalize}"
    else
      preview = '...'
    end

    q = {
      'key' => {
        'id' => external_id,
        'remoteJid' => remote_jid,
        'fromMe' => from_me
      }
    }
    # FORCE text conversation to prevent media resend behavior
    q['message'] = { 'conversation' => preview }

    Rails.logger.info("[Evolution] build_quoted_for: parent_id=#{parent&.id} preview='#{preview}' q=#{q.inspect}")
    q
  end

  def safely_build_quoted_for(message)
    build_quoted_for(message)
  rescue StandardError => e
    Rails.logger.warn("[Evolution] build_quoted_for failed: #{e.class}: #{e.message}")
    nil
  end

  def persist_message_id_from(resp)
    return if @evolution_message_id.present?

    eid = extract_message_id(resp)
    return if eid.blank?

    @evolution_message_id = eid
    @message.update!(source_id: eid)
    Rails.logger.info("[Evolution] linked message #{@message.id} to source_id=#{eid}")
  end

  def extract_message_id(resp)
    h = if resp.is_a?(Hash)
          resp
        else
          begin
            JSON.parse(resp)
          rescue StandardError
            {}
          end
        end
    h.dig('key', 'id') ||
      h['messageId'] ||
      h.dig('data', 'messageId') ||
      h['id'] ||
      h.dig('data', 'id')
  end

  def mark_dispatched!
    h = @message.additional_attributes.to_h
    h['evolution_dispatched'] = true
    @message.update_columns(additional_attributes: h, updated_at: Time.current)
  end

  def mark_as_blocked!
    reason = if @message.private?
               'Private messages are not sent to contacts'
             else
               "Message type '#{@message.message_type}' cannot be sent via Evolution"
             end

    Rails.logger.info("[Evolution::SendMessageService] Blocked msg=#{@message.id}: #{reason}")
    update_message_status!(message: @message, status: 'failed', external_error: reason)
  end

  def record_send_error!(error:, kind:, payload: {})
    error_details = Evolution::ErrorHandler.handle_send_error(error)

    Rails.logger.error(
      "[Evolution::SendMessageService] send_#{kind} error: " \
      "type=#{error_details[:error_type]} " \
      "user_msg='#{error_details[:user_message]}' " \
      "technical='#{error_details[:technical_message]}' " \
      "payload=#{payload.inspect}"
    )

    update_message_status!(
      message: @message,
      status: 'failed',
      external_error: error_details[:user_message]
    )
  end

  def try_compress_video(attachment)
    return nil unless defined?(VideoCompressor)

    compressed_blob = nil

    attachment.open do |temp_file|
      input_path = temp_file.path
      output_path = "#{input_path}_compressed.mp4"

      begin
        VideoCompressor.compress!(input_path: input_path, output_path: output_path)

        if File.exist?(output_path) && File.size?(output_path)
          compressed_blob = ActiveStorage::Blob.create_and_upload!(
            io: File.open(output_path),
            filename: "compressed_#{attachment.filename}",
            content_type: attachment.content_type
          )
        end
      rescue StandardError => e
        Rails.logger.error "[Evolution] Compression internal error: #{e.message}"
      ensure
        FileUtils.rm_f(output_path) if output_path && File.exist?(output_path)
      end
    end

    compressed_blob
  end

  def encode_blob_base64(blob)
    if blob.respond_to?(:open)
      blob.open { |io| Base64.strict_encode64(io.read) }
    else
      Base64.strict_encode64(blob.download)
    end
  end
end
