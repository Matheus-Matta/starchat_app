class Cosmos::Llm::FileProcessingService < Llm::BaseOpenAiService
  def initialize(document)
    super()
    @document = document
  end

  def process
    return if document.openai_file_id.present?

    file_id = upload_file_to_openai
    raise CustomExceptions::FileUploadError, I18n.t('cosmos.documents.file_upload_failed') if file_id.blank?

    document.store_openai_file_id(file_id)
  end

  private

  attr_reader :document

  def upload_file_to_openai
    with_tempfile do |temp_file|
      response = @client.files.upload(
        parameters: {
          file: temp_file,
          purpose: 'assistants'
        }
      )
      response['id']
    end
  end

  def with_tempfile(&)
    extension = File.extname(document.pdf_file.filename.to_s)
    Tempfile.create(['cosmos_upload', extension], binmode: true) do |temp_file|
      temp_file.write(document.pdf_file.download)
      temp_file.close

      File.open(temp_file.path, 'rb', &)
    end
  end
end
