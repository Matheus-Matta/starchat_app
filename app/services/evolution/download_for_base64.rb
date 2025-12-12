# frozen_string_literal: true

require 'base64'
require 'stringio'

module Evolution::DownloadForBase64
  def download_for_base64(b64, filename:, content_type: nil, identify: true)
    str = b64.to_s

    if str.start_with?('data:')
      header, data = str.split(',', 2)
      if content_type.blank?
        if (m = header.match(%r{\Adata:(?<ct>[^;]+);base64}))
          content_type = m[:ct]
        end
      end
      str = data
    end

    binary = Base64.strict_decode64(str)

    io = StringIO.new(binary)

    if identify && content_type.blank?
      begin
        content_type = Marcel::MimeType.for(io, name: filename)
      rescue
      ensure
        io.rewind
      end
    end

    content_type ||= 'application/octet-stream'

    ActiveStorage::Blob.create_and_upload!(
      io:          io,
      filename:    filename,
      content_type: content_type
    )
  end
end
