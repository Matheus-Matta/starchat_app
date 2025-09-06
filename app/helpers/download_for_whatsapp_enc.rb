# frozen_string_literal: true
module DownloadForWhatsappEnc
  require "down"
  require "openssl"
  require "tempfile"
  require "securerandom"
  require "marcel"
  require "base64"

  # Baixa mídia do WhatsApp (mmg.whatsapp.net), valida MAC e decifra (AES-256-CBC).
  # Deriva iv/cipher_key/mac_key via HKDF(SHA-256) a partir do mediaKey.
  #
  # Params:
  #   url:         String  (mmg.whatsapp.net ...)
  #   media_key:   String  (base64 do payload: "mediaKey")
  #   media_type:  Symbol  :image | :video | :audio | :document | :sticker
  #   filename:    String? (opcional)
  #   content_type:String? (opcional, ex. "image/jpeg")
  #   headers:     Hash    (ex.: Authorization)
  #   identify:    Boolean (default false)
  #
  # Retorna: ActiveStorage::Blob
  #
  def download_for_whatsapp_enc(url:, media_key:, media_type:, filename: nil,
                                content_type: nil, headers: {}, identify: false)

    mk  = Base64.strict_decode64(media_key.to_s) # 32 bytes
    info = hkdf_info_for(media_type)             # "WhatsApp Image Keys", etc.

    # HKDF(SHA-256), salt = 32 bytes zero, length = 112 (IV16 + AES32 + MAC32 + ref32)
    prk_len = 112
    salt    = "\x00" * 32
    okm     = hkdf_sha256(ikm: mk, salt: salt, info: info, length: prk_len)

    iv         = okm[0, 16]
    cipher_key = okm[16, 32]
    mac_key    = okm[48, 32]
    # ref_key  = okm[80, 32] => não usado aqui

    # Baixa o arquivo .enc inteiro (tamanho típico é pequeno para imagens)
    enc_io = Down.download(url, headers: headers)
    enc_bin = enc_io.read
    enc_io.close!

    # Separa MAC (últimos 10 bytes) e ciphertext
    raise "Encrypted file too short" if enc_bin.bytesize <= 10
    mac_provided = enc_bin[-10, 10]
    ciphertext   = enc_bin[0...-10]

    # Valida MAC: HMAC-SHA256(mac_key, iv + ciphertext), compara primeiros 10 bytes
    mac_calc = OpenSSL::HMAC.digest("sha256", mac_key, iv + ciphertext)[0, 10]
    raise OpenSSL::Cipher::CipherError, "Invalid MAC" unless secure_cmp(mac_calc, mac_provided)

    # Decifra AES-256-CBC (PKCS#7)
    cipher = OpenSSL::Cipher.new("aes-256-cbc")
    cipher.decrypt
    cipher.key = cipher_key
    cipher.iv  = iv

    out = Tempfile.new(["wa-dec-", SecureRandom.hex(4)])
    out.binmode
    out.write(cipher.update(ciphertext))
    out.write(cipher.final)
    out.rewind

    resolved_filename = filename.presence || "file-#{SecureRandom.hex(4)}"
    resolved_ct       = content_type.presence ||
                        Marcel::MimeType.for(out, name: resolved_filename) ||
                        "application/octet-stream"

    ActiveStorage::Blob.create_and_upload!(
      io:           out,
      filename:     resolved_filename,
      content_type: resolved_ct,
      identify:     identify
    )
  ensure
    begin out.close! if defined?(out) && out; rescue; end
    begin enc_io.close! if defined?(enc_io) && enc_io; rescue; end
  end

  private

  # HKDF(SHA-256) compatível com OpenSSL (usa OpenSSL::KDF.hkdf se disponível)
  def hkdf_sha256(ikm:, salt:, info:, length:)
    if OpenSSL::KDF.respond_to?(:hkdf)
      return OpenSSL::KDF.hkdf(ikm, hash: "SHA256", salt: salt, info: info, length: length)
    end
    # Fallback HKDF manual (RFC 5869)
    prk = OpenSSL::HMAC.digest("sha256", salt, ikm)
    t   = +""
    okm = +""
    (1..((length.to_f / 32).ceil)).each do |i|
      t = OpenSSL::HMAC.digest("sha256", prk, t + info + i.chr)
      okm << t
    end
    okm[0, length]
  end

  def hkdf_info_for(media_type)
    case media_type.to_sym
    when :image, :sticker then "WhatsApp Image Keys"
    when :video           then "WhatsApp Video Keys"
    when :audio           then "WhatsApp Audio Keys"
    when :document        then "WhatsApp Document Keys"
    else                      "WhatsApp Image Keys"
    end
  end

  # Comparação em tempo constante
  def secure_cmp(a, b)
    return false unless a.bytesize == b.bytesize
    l = a.unpack("C*").zip(b.unpack("C*")).reduce(0) { |acc, (x, y)| acc | (x ^ y) }
    l.zero?
  end
end
