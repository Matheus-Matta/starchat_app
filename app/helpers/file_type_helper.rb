module FileTypeHelper
  # NOTE: video, audio, image, etc are filetypes previewable in frontend
  def file_type(content_type)
    return :image if image_file?(content_type)
    return :video if video_file?(content_type)
    return :audio if content_type&.include?('audio/')

    :file
  end

  # Used in case of DIRECT_UPLOADS_ENABLED=true
  def file_type_by_signed_id(signed_id)
    blob = ActiveStorage::Blob.find_signed(signed_id)
    file_type(blob&.content_type)
  end

  def image_file?(content_type)
    [
      'image/jpeg',
      'image/jpg',
      'image/png',
      'image/gif',
      'image/bmp',
      'image/webp',
      'image'
    ].include?(content_type)
  end

  def video_file?(content_type)
    [
      'video/ogg',
      'video/mp4',
      'video/webm',
      'video/quicktime',
      'video'
    ].include?(content_type)
  end

  def content_type_for_ext(ext)
    case ext.to_s.downcase.delete_prefix('.')
    when 'jpg', 'jpeg' then 'image/jpeg'
    when 'mp4'         then 'video/mp4'
    when 'ogg', 'opus' then 'audio/ogg'
    else                    'application/octet-stream'
    end
  end
end
