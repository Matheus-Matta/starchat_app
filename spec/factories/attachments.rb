FactoryBot.define do
  factory :attachment do
    account
    message
    file_type { :image }
    external_url { nil }
    
    after(:build) do |attachment|
      filename = case attachment.file_type.to_sym
                 when :audio then 'audio.mp3' 
                 when :video then 'video.mp4'
                 when :file then 'file.pdf'
                 else 'avatar.png'
                 end
                 
      content_type = case attachment.file_type.to_sym
                     when :audio then 'audio/mpeg'
                     when :video then 'video/mp4'
                     when :file then 'application/pdf'
                     else 'image/png'
                     end
                     
      path = case attachment.file_type.to_sym
             when :audio then 'spec/assets/audio.mp3'
             when :video then 'spec/assets/video.mp4'
             else 'spec/assets/avatar.png'
             end
             
      # Fallback to avatar.png if specific asset doesn't exist
      path = 'spec/assets/avatar.png' unless File.exist?(Rails.root.join(path))

      attachment.file.attach(
        io: File.open(Rails.root.join(path)),
        filename: filename,
        content_type: content_type
      )
    end
  end
end
