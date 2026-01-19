# frozen_string_literal: true

module DownloadForEnc
  require 'down'
  require 'openssl'
  require 'tempfile'
  require 'securerandom'
  require 'marcel'

  # Baixa um arquivo .enc via HTTP(S), descriptografa (AES-256-GCM) em streaming
  # e sobe o resultado para o Active Storage. Retorna um ActiveStorage::Blob.
  #
  # Params:
  # - url:           String (http/https)
  # - key:           String (hex OU base64)  => 32 bytes
  # - iv:            String (hex OU base64)  => 12 bytes (recomendado p/ GCM)
  # - tag:           String (hex OU base64)  => 16 bytes (128-bit auth tag)
  # - aad:           String (opcional; bytes ou base64/hex)
  # - filename:      String (opcional; default gera aleatório)
  # - content_type:  String (opcional; se não vier, Marcel detecta)
  # - headers:       Hash   (opcional; Authorization etc.)
  # - chunk_size:    Integer (bytes; default 1MB)
  # - identify:      Boolean (default false; se já passamos content_type)
  #
  def download_for_enc_gcm(url:, key:, iv:, tag:, aad: nil,
                           filename: nil, content_type: nil, headers: {},
                           chunk_size: 1 << 20, identify: false)
    key_bin  = decode_bytes(key)
    iv_bin   = decode_bytes(iv)
    tag_bin  = decode_bytes(tag)
    aad_bin  = aad.nil? ? nil : decode_bytes(aad)

    out = Tempfile.new(['dec-', SecureRandom.hex(4)])
    out.binmode

    Down.open(url, headers: headers) do |remote|
      cipher = OpenSSL::Cipher.new('aes-256-gcm')
      cipher.decrypt
      cipher.key = key_bin
      cipher.iv  = iv_bin
      cipher.auth_tag  = tag_bin
      cipher.auth_data = aad_bin if aad_bin

      while (chunk = remote.read(chunk_size))
        out.write(cipher.update(chunk))
      end
      out.write(cipher.final)
      out.rewind
    end

    resolved_filename = filename.presence || "file-#{SecureRandom.hex(4)}"
    resolved_ct = content_type.presence ||
                  Marcel::MimeType.for(out, name: resolved_filename) ||
                  'application/octet-stream'

    blob = ActiveStorage::Blob.create_and_upload!(
      io: out,
      filename: resolved_filename,
      content_type: resolved_ct,
      identify: identify
    )

    blob
  rescue OpenSSL::Cipher::CipherError => e
    raise e
  ensure
    begin
      out.close! if defined?(out) && out
    rescue StandardError
      # no-op
    end
  end

  private

  def decode_bytes(s)
    str = s.to_s
    if str.match?(/\A[0-9a-fA-F]+\z/) && (str.size.even?)
      [str].pack('H*')
    else
      begin
        Base64.strict_decode64(str)
      rescue StandardError
        str
      end
    end
  end
end
