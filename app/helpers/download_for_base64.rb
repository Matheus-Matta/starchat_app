# frozen_string_literal: true

module DownloadForBase64
  require 'base64'
  require 'stringio'
  require 'securerandom'
  require 'marcel'

  def download_for_base64(data_url_or_b64, filename: nil, content_type: nil, identify: false)
    ct_hint = nil
    b64     = data_url_or_b64.to_s

    if b64.start_with?('data:') && b64.include?(';base64,')
      ct_hint = b64[/\Adata:([^;]+);/, 1]
      b64     = b64.split(',', 2).last
    end

    bin = Base64.decode64(b64)

    resolved_filename = filename.presence || "file-#{SecureRandom.hex(4)}"
    resolved_ct       = content_type.presence ||
                        ct_hint.presence ||
                        Marcel::MimeType.for(StringIO.new(bin), name: resolved_filename) ||
                        'application/octet-stream'

    io = StringIO.new(bin)
    io.rewind

    ActiveStorage::Blob.create_and_upload!(
      io: io,
      filename: resolved_filename,
      content_type: resolved_ct,
      identify: identify
    )
  end
end
