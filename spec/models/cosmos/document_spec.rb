require 'rails_helper'

RSpec.describe Cosmos::Document, type: :model do
  describe 'file format validation' do
    let(:document) { Cosmos::Document.new }

    context 'when attaching files' do
      before do
        # Stubbing blob content type since we are simulating attachment
        allow(document).to receive(:validate_file_attachment) # Skip size check mock
      end

      it 'allows XLSX' do
        # We simulate the blob check indirectly or via mock
        blob = double('blob', content_type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', byte_size: 1000)
        attachment = double('attachment', attached?: true, blob: blob)
        allow(document).to receive(:pdf_file).and_return(attachment)
        
        document.send(:validate_file_format)
        expect(document.errors[:pdf_file]).to be_empty
      end

      it 'allows CSV' do
        blob = double('blob', content_type: 'text/csv', byte_size: 1000)
        attachment = double('attachment', attached?: true, blob: blob)
        allow(document).to receive(:pdf_file).and_return(attachment)
        
        document.send(:validate_file_format)
        expect(document.errors[:pdf_file]).to be_empty
      end

      it 'rejects JPG' do
        blob = double('blob', content_type: 'image/jpeg', byte_size: 1000)
        attachment = double('attachment', attached?: true, blob: blob)
        allow(document).to receive(:pdf_file).and_return(attachment)
        
        document.send(:validate_file_format)
        expect(document.errors[:pdf_file]).to include(I18n.t('cosmos.documents.file_format_error'))
      end
    end
  end

  describe '#file_document?' do
    let(:document) { Cosmos::Document.new }

    it 'returns true if pdf_file is attached' do
      allow(document.pdf_file).to receive(:attached?).and_return(true)
      expect(document.file_document?).to be true
    end

    it 'returns true if external_link ends with .pdf' do
      document.external_link = 'http://example.com/file.pdf'
      expect(document.file_document?).to be true
    end

    it 'returns true if external_link ends with .xlsx' do
      document.external_link = 'http://example.com/file.xlsx'
      expect(document.file_document?).to be true
    end

    it 'returns false for html link' do
      document.external_link = 'http://example.com/page'
      expect(document.file_document?).to be false
    end
  end

  describe '#should_enqueue_response_builder?' do
    let(:document) { Cosmos::Document.new(status: :available) }

    it 'returns true if status available and file_id present' do
      document.content = nil
      allow(document).to receive(:openai_file_id).and_return('file-123')
      allow(document).to receive(:saved_change_to_status?).and_return(true)
      
      expect(document.send(:should_enqueue_response_builder?)).to be true
    end
  end
end
