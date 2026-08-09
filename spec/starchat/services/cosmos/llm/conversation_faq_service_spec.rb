require 'rails_helper'

RSpec.describe Cosmos::Llm::ConversationFaqService do
  let(:cosmos_assistant) { create(:cosmos_assistant) }
  let(:conversation) { create(:conversation, account: cosmos_assistant.account, first_reply_created_at: Time.zone.now) }
  let(:service) { described_class.new(cosmos_assistant, conversation) }
  let(:client) { instance_double(OpenAI::Client) }
  let(:embedding_service) { instance_double(Cosmos::Llm::EmbeddingService) }
  let(:mock_chat) { instance_double(RubyLLM::Chat) }

  before do
    create(:installation_config) { create(:installation_config, name: 'COSMOS_OPEN_AI_API_KEY', value: 'test-key') }
    allow(OpenAI::Client).to receive(:new).and_return(client)
    allow(Cosmos::Llm::EmbeddingService).to receive(:new).and_return(embedding_service)
    allow(RubyLLM).to receive(:chat).and_return(mock_chat)
    allow(mock_chat).to receive(:with_temperature).and_return(mock_chat)
    allow(mock_chat).to receive(:with_params).and_return(mock_chat)
    allow(mock_chat).to receive(:with_instructions).and_return(mock_chat)
  end

  describe '#generate_and_deduplicate' do
    let(:sample_faqs) do
      [
        { 'question' => 'What is the purpose?', 'answer' => 'To help users.' },
        { 'question' => 'How does it work?', 'answer' => 'Through AI.' }
      ]
    end

    let(:openai_response) do
      {
        'choices' => [
          {
            'message' => {
              'content' => { faqs: sample_faqs }.to_json
            }
          }
        ]
      }
    end

    context 'when successful' do
      before do
        allow(client).to receive(:chat).and_return(openai_response)
        allow(embedding_service).to receive(:get_embedding).and_return([0.1, 0.2, 0.3])
        allow(cosmos_assistant.responses).to receive(:nearest_neighbors).and_return([])
      end

      it 'creates new FAQs' do
end

      it 'uses the conversation FAQ generation feature model' do
        expect(RubyLLM).to receive(:chat).with(
          model: Llm::Models.default_model_for('conversation_faq_generation')
        ).and_return(mock_chat)

        described_class.new(cosmos_assistant, conversation).generate_suggestions
      end

      it 'uses the conversation FAQ default ahead of the legacy global installation model' do
        create(:installation_config, name: 'COSMOS_OPEN_AI_MODEL', value: 'gpt-4.1-mini')

        expect(RubyLLM).to receive(:chat).with(
          model: Llm::Models.default_model_for('conversation_faq_generation')
        ).and_return(mock_chat)

        described_class.new(cosmos_assistant, conversation).generate_suggestions
      end

      it 'keeps account conversation FAQ model overrides ahead of the feature default' do
        create(:installation_config, name: 'COSMOS_OPEN_AI_MODEL', value: 'gpt-4.1')
        conversation.account.update!(cosmos_models: { 'conversation_faq_generation' => 'gpt-4.1-mini' })

        expect(RubyLLM).to receive(:chat).with(model: 'gpt-4.1-mini').and_return(mock_chat)

        described_class.new(cosmos_assistant, conversation).generate_suggestions
      end

      it 'resolves the feature model from the conversation account' do
        expect(Llm::FeatureRouter).to receive(:resolve).with(
          feature: 'conversation_faq_generation',
          account: conversation.account
        ).and_call_original

        described_class.new(cosmos_assistant, conversation).generate_suggestions
      end

      it 'sends only customer and human support agent messages to the LLM' do
        create(:message, conversation: conversation, account: conversation.account, inbox: conversation.inbox,
                         sender: create(:contact, account: conversation.account), message_type: :incoming,
                         content: 'Customer question')
        create(:message, :bot_message, conversation: conversation, account: conversation.account, inbox: conversation.inbox,
                                       content: 'Bot answer that should not become knowledge')
        create(:message, conversation: conversation, account: conversation.account, inbox: conversation.inbox,
                         sender: create(:user, account: conversation.account), message_type: :outgoing,
                         content: 'Human answer')
        create(:message, conversation: conversation, account: conversation.account, inbox: conversation.inbox,
                         sender: create(:user, account: conversation.account), message_type: :outgoing,
                         private: true, content: 'Private note')
        create(:message, conversation: conversation, account: conversation.account, inbox: conversation.inbox,
                         message_type: :activity, content: 'Activity message')

        service.generate_suggestions

        expected_content = satisfy do |content|
          content.include?('User: Customer question') &&
            content.include?('Support Agent: Human answer') &&
            content.exclude?('Bot answer that should not become knowledge') &&
            content.exclude?('Private note') &&
            content.exclude?('Activity message')
        end
        expect(mock_chat).to have_received(:ask).with(expected_content)
      end

      it 'keeps external echo outgoing replies from native channels in the LLM transcript' do
        create(:message, conversation: conversation, account: conversation.account, inbox: conversation.inbox,
                         sender: create(:contact, account: conversation.account), message_type: :incoming,
                         content: 'Customer asks in a native channel')
        create(:message, conversation: conversation, account: conversation.account, inbox: conversation.inbox,
                         sender: nil, message_type: :outgoing, content: 'Human replied from the native app',
                         content_attributes: { external_echo: true })

        service.generate_suggestions

        expected_content = satisfy do |content|
          content.include?('User: Customer asks in a native channel') &&
            content.include?('Support Agent: Human replied from the native app')
        end
        expect(mock_chat).to have_received(:ask).with(expected_content)
      end

      it 'uses the human-only conversation transcript for instrumentation' do
        create(:message, conversation: conversation, account: conversation.account, inbox: conversation.inbox,
                         sender: create(:contact, account: conversation.account), message_type: :incoming,
                         content: 'Customer asks something')
        create(:message, :bot_message, conversation: conversation, account: conversation.account, inbox: conversation.inbox,
                                       content: 'Bot-only answer')
        create(:message, conversation: conversation, account: conversation.account, inbox: conversation.inbox,
                         sender: create(:user, account: conversation.account), message_type: :outgoing,
                         content: 'Agent gives a public answer')

        expect(service).to receive(:instrument_llm_call) do |params, &block|
          user_message = params[:messages].find { |message| message[:role] == 'user' }[:content]

          expect(user_message).to include('User: Customer asks something')
          expect(user_message).to include('Support Agent: Agent gives a public answer')
          expect(user_message).not_to include('Bot-only answer')

          block.call
        end

        service.generate_suggestions
      end

      it 'creates suggestions instead of trusted FAQs for valid conversation content' do
        expect do
          service.generate_suggestions
        end.to change(cosmos_assistant.faq_suggestions, :count).by(2)
        expect(Cosmos::FaqObservation.count).to eq(2)
        expect(cosmos_assistant.responses.count).to be_zero
      end

      it 'saves the correct FAQ content' do
        service.generate_and_deduplicate
        expect(
          cosmos_assistant.faq_suggestions.pluck(:question, :answer, :status, :source_count, :language)
        ).to contain_exactly(
          ['What is the purpose?', 'To help users.', 'open', 1, 'en'],
          ['How does it work?', 'Through AI.', 'open', 1, 'en']
        )
        expect(Cosmos::FaqObservation.attached.pluck(:conversation_id, :language)).to contain_exactly(
          [conversation.id, 'en'], [conversation.id, 'en']
        )
      end
    end

    context 'without human interaction' do
      let(:conversation) { create(:conversation) }

      it 'returns an empty array without generating FAQs' do
        expect(service.generate_suggestions).to eq([])
      end
    end

    context 'when finding duplicates' do
      let(:existing_response) do
        create(:cosmos_assistant_response, assistant: cosmos_assistant, account: cosmos_assistant.account,
                                            question: 'Similar question', answer: 'Similar answer', embedding: embedding_one)
      end
      let(:similar_neighbor) do
        # Using OpenStruct here to mock as the  :AssistantResponse does not implement
        # neighbor_distance as a method or attribute rather it is returned directly
        # from SQL query in neighbor gem
        OpenStruct.new(
          id: 1,
          question: existing_response.question,
          answer: existing_response.answer,
          neighbor_distance: 0.1
        )
      end

      before do
        allow(client).to receive(:chat).and_return(openai_response)
        allow(embedding_service).to receive(:get_embedding).and_return([0.1, 0.2, 0.3])
        allow(cosmos_assistant.responses).to receive(:nearest_neighbors).and_return([similar_neighbor])
      end

      it 'filters out duplicate FAQs' do
        expect do
          service.generate_suggestions
        end.to change(cosmos_assistant.faq_suggestions, :count).by(1)

        expect(cosmos_assistant.faq_suggestions.pluck(:language)).to contain_exactly('en', 'pt')
        expect(existing_suggestion.reload.source_count).to eq(1)
      end
    end

    context 'when an open suggestion uses another locale variant of the same language' do
      let(:account) { create(:account, locale: 'pt_BR') }
      let(:cosmos_assistant) { create(:cosmos_assistant, account: account) }
      let(:conversation) { create(:conversation, account: account, first_reply_created_at: Time.zone.now) }
      let(:sample_faqs) { [{ 'question' => 'Como ativo o recurso?', 'answer' => 'Ative nas configuracoes.' }] }
      let(:existing_suggestion) do
        cosmos_assistant.faq_suggestions.create!(
          question: 'Como habilito o recurso?',
          answer: 'Ative nas configuracoes.',
          embedding: embedding_one,
          language: 'pt',
          source_count: 1
        )
      end
      let(:match_response) { instance_double(RubyLLM::Message, content: { same_faq: true }.to_json) }

      before do
        existing_suggestion
        allow(embedding_service).to receive(:get_embedding).and_return(embedding_one)
        allow(mock_chat).to receive(:ask) do |input|
          input.start_with?('{') ? match_response : mock_response
        end
      end

      it 'attaches the observation to the existing base-language suggestion' do
        expect do
          service.generate_suggestions
        end.to change(existing_suggestion.observations, :count).by(1)

        expect(existing_suggestion.reload.source_count).to eq(2)
        expect(cosmos_assistant.faq_suggestions.count).to eq(1)
        expect(existing_suggestion.observations.last.language).to eq('pt')
      end
    end

    context 'when a similar approved FAQ uses another language' do
      let(:sample_faqs) { [{ 'question' => 'Como ativo o recurso?', 'answer' => 'Ative nas configuracoes.' }] }
      let(:match_response) { instance_double(RubyLLM::Message, content: { same_faq: true }.to_json) }

      before do
        create(:cosmos_assistant_response, assistant: cosmos_assistant, account: cosmos_assistant.account,
                                            question: 'How do I enable the feature?', answer: 'Turn it on in settings.',
                                            embedding: embedding_one)
        conversation.update!(additional_attributes: { conversation_language: 'pt-BR' })
        allow(embedding_service).to receive(:get_embedding).and_return(embedding_one)
        allow(mock_chat).to receive(:ask) do |input|
          input.start_with?('{') ? match_response : mock_response
        end
      end

      it 'deduplicates against the approved FAQ' do
        expect do
          service.generate_suggestions
        end.to change(Cosmos::FaqObservation.discarded, :count).by(1)
        expect(cosmos_assistant.faq_suggestions.count).to be_zero
      end
    end

    context 'when conversation and account locales share a base language' do
      let(:account) { create(:account, locale: 'pt_BR') }
      let(:cosmos_assistant) { create(:cosmos_assistant, account: account) }
      let(:conversation) do
        create(:conversation, account: account, first_reply_created_at: Time.zone.now,
                              additional_attributes: { conversation_language: 'pt' })
      end
      let!(:existing_response) do
        create(:cosmos_assistant_response, assistant: cosmos_assistant, account: account,
                                            question: 'Como ativo o recurso?', answer: 'Ative nas configuracoes.',
                                            embedding: embedding_one)
      end
      let(:match_response) { instance_double(RubyLLM::Message, content: { same_faq: true }.to_json) }

      before do
        existing_response
        allow(embedding_service).to receive(:get_embedding).and_return(embedding_one)
        allow(mock_chat).to receive(:ask) do |input|
          input.start_with?('{') ? match_response : mock_response
        end
      end

      it 'deduplicates against approved FAQs in the same base language' do
        expect do
          service.generate_suggestions
        end.to change(Cosmos::FaqObservation.discarded, :count).by(2)
        expect(cosmos_assistant.faq_suggestions.count).to be_zero
      end
    end

    context 'when OpenAI API fails' do
      before do
        allow(client).to receive(:chat).and_raise(OpenAI::Error.new('API Error'))
      end

      it 'handles the error and returns empty array' do
        expect(Rails.logger).to receive(:error).with('OpenAI API Error: API Error')
        expect(service.generate_and_deduplicate).to eq([])
      end
    end

    context 'when JSON parsing fails' do
      let(:invalid_response) do
        {
          'choices' => [
            {
              'message' => {
                'content' => 'invalid json'
              }
            }
          ]
        }
      end

      before do
        allow(client).to receive(:chat).and_return(invalid_response)
      end

      it 'handles JSON parsing errors' do
        expect(Rails.logger).to receive(:error).with(/Error in parsing GPT processed response:/)
        expect(service.generate_suggestions).to eq([])
      end
    end
  end

  describe '#chat_parameters' do
    it 'includes correct model and response format' do
      params = service.send(:chat_parameters)
      expect(params[:model]).to eq('gpt-4o-mini')
      expect(params[:response_format]).to eq({ type: 'json_object' })
    end

    it 'includes system prompt and conversation content' do
      allow(Cosmos::Llm::SystemPromptsService).to receive(:conversation_faq_generator).and_return('system prompt')
      params = service.send(:chat_parameters)

      expect(params[:messages]).to include(
        { role: 'system', content: 'system prompt' },
        { role: 'user', content: conversation.to_llm_text }
      )
    end

    context 'when conversation has different language' do
      let(:account) { create(:account, locale: 'fr') }
      let(:cosmos_assistant) { create(:cosmos_assistant, account: account) }
      let(:conversation) do
        create(:conversation, account: account,
                              first_reply_created_at: Time.zone.now)
      end

      it 'includes system prompt with correct language' do
        allow(Cosmos::Llm::SystemPromptsService).to receive(:conversation_faq_generator)
          .with('french')
          .and_return('system prompt in french')

        params = service.send(:chat_parameters)

        expect(params[:messages]).to include(
          { role: 'system', content: 'system prompt in french' }
        )
      end
    end
  end
end
