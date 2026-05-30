class Cosmos::Llm::FileProcessingService < Llm::BaseOpenAiService
  def initialize(document)
    super()
    @document = document
  end

  def process
    return if document.openai_file_id.present?

    file_id = upload_file_to_openai
    raise CustomExceptions::Pdf::UploadError, I18n.t('cosmos.documents.file_upload_failed') if file_id.blank?

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

  def with_tempfile
    Tempfile.create(['pdf_upload', '.pdf'], binmode: true) do |temp_file|
      document.pdf_file.blob.open do |blob_file|
        IO.copy_stream(blob_file, temp_file)
      end

      temp_file.flush
      temp_file.rewind

      yield temp_file
    end
  end
end

