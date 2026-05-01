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
      instrument_file_upload do
        response = @client.files.upload(
          parameters: {
            file: temp_file,
            purpose: 'assistants'
          }
        )
        response['id']
      end
    end
  end

  def with_tempfile(&)
    extension = File.extname(document.pdf_file.filename.to_s)
    Tempfile.create(['cosmos_upload', extension], binmode: true) do |temp_file|
      temp_file.write(document.pdf_file.download)
      temp_file.close

    tracer.in_span('llm.file.upload') do |span|
      span.set_attribute('gen_ai.provider', 'openai')
      span.set_attribute('file.purpose', 'assistants')
      span.set_attribute(ATTR_LANGFUSE_USER_ID, document.account_id.to_s)
      span.set_attribute(ATTR_LANGFUSE_TAGS, ['pdf_upload'].to_json)
      span.set_attribute(format(ATTR_LANGFUSE_METADATA, 'document_id'), document.id.to_s)
      file_id = yield
      span.set_attribute('file.id', file_id) if file_id
      file_id
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
