require 'rails_helper'

RSpec.describe Cosmos::Llm::FaqGeneratorService do
  let(:content) { 'Sample content for FAQ generation' }
  let(:language) { 'english' }
  let(:service) { described_class.new(content, language) }
  let(:mock_chat) { instance_double(RubyLLM::Chat) }
  let(:sample_faqs) do
    [
      { 'question' => 'What is this service?', 'answer' => 'It generates FAQs.' },
      { 'question' => 'How does it work?', 'answer' => 'Using AI technology.' }
    ]
  end
  let(:mock_response) do
    instance_double(RubyLLM::Message, content: { faqs: sample_faqs }.to_json)
  end

  before do
    create(:installation_config, name: 'COSMOS_OPEN_AI_API_KEY', value: 'test-key')
    allow(OpenAI::Client).to receive(:new).and_return(client)
  end

  describe '#generate' do
    context 'when successful' do
      before do
        allow(client).to receive(:chat).and_return(openai_response)
        allow(Cosmos::Llm::SystemPromptsService).to receive(:faq_generator).and_return('system prompt')
      end

      it 'returns parsed FAQs' do
        result = service.generate
        expect(result).to eq(sample_faqs)
      end

      it 'sends content to LLM with JSON response format' do
        expect(mock_chat).to receive(:with_params).with(response_format: { type: 'json_object' }).and_return(mock_chat)
        service.generate
      end

      it 'calls SystemPromptsService with correct language' do
        expect(Cosmos::Llm::SystemPromptsService).to receive(:faq_generator).with(language)
        service.generate
      end
    end

    context 'with different language' do
      let(:language) { 'spanish' }

      it 'passes the correct language to SystemPromptsService' do
        expect(Cosmos::Llm::SystemPromptsService).to receive(:faq_generator).with('spanish')
        service.generate
      end
    end

    context 'when LLM API fails' do
      before do
        allow(mock_chat).to receive(:ask).and_raise(RubyLLM::Error.new(nil, 'API Error'))
        allow(Rails.logger).to receive(:error)
      end

      it 'returns empty array and logs the error' do
        expect(Rails.logger).to receive(:error).with('LLM API Error: API Error')
        expect(service.generate).to eq([])
      end
    end

    context 'when response content is nil' do
      let(:nil_response) { instance_double(RubyLLM::Message, content: nil) }

      before do
        allow(mock_chat).to receive(:ask).and_return(nil_response)
      end

      it 'returns empty array' do
        expect(service.generate).to eq([])
      end
    end

    context 'when JSON parsing fails' do
      let(:invalid_response) { instance_double(RubyLLM::Message, content: 'invalid json') }

      before do
        allow(mock_chat).to receive(:ask).and_return(invalid_response)
      end

      it 'logs error and returns empty array' do
        expect(Rails.logger).to receive(:error).with(/Error in parsing GPT processed response:/)
        expect(service.generate).to eq([])
      end
    end

    context 'when response is missing faqs key' do
      let(:missing_key_response) { instance_double(RubyLLM::Message, content: '{"data": []}') }

      before do
        allow(mock_chat).to receive(:ask).and_return(missing_key_response)
      end

      it 'returns empty array via KeyError rescue' do
        expect(service.generate).to eq([])
      end
    end
  end
end
