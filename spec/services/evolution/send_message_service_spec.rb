# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Evolution::SendMessageService do
  let(:account) { create(:account) }
  let(:channel) { create(:channel_evolution, account: account) }
  let(:inbox) { create(:inbox, channel: channel, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox, source_id: '5521999887766') }
  let(:conversation) { create(:conversation, contact: contact, inbox: inbox, contact_inbox: contact_inbox, account: account) }
  
  let(:client_double) { instance_double(Evolution::Client) }
  
  before do
    allow(Evolution::Client).to receive(:new).and_return(client_double)
    stub_const('ENV', ENV.to_hash.merge(
      'EVOLUTION_BASE_URL' => 'https://api.evolution.test',
      'EVOLUTION_API_KEY' => 'test-key-123'
    ))
  end

  describe '#perform com mensagem de texto' do
    it 'envia mensagem de texto simples' do
      message = create(:message, conversation: conversation, message_type: :outgoing, content: 'Olá, teste!')
      
      expect(client_double).to receive(:send_text)
        .with(channel.instance_name, number: '5521999887766', text: 'Olá, teste!', quoted: nil)
        .and_return({ 'key' => { 'id' => 'msg_123' } })

      service = described_class.new(message: message)
      service.perform

      expect(message.reload.source_id).to eq('msg_123')
      expect(message.status).to eq('delivered')
    end

    it 'não envia mensagem privada (nota interna)' do
      message = create(:message, conversation: conversation, message_type: :outgoing, private: true, content: 'Nota interna')
      
      expect(client_double).not_to receive(:send_text)

      service = described_class.new(message: message)
      service.perform
    end

    it 'não envia mensagem já despachada' do
      message = create(:message, conversation: conversation, message_type: :outgoing, source_id: 'already_sent', content: 'Teste')
      
      expect(client_double).not_to receive(:send_text)

      service = described_class.new(message: message)
      service.perform
    end
  end

  describe '#perform com anexos (mídia)' do
    let(:message) { create(:message, conversation: conversation, message_type: :outgoing, content: '') }
    
    context 'quando envia imagem via URL (comportamento prioritário)' do
      it 'envia URL diretamente para a API Evolution' do
        # Criar anexo de imagem
        attachment = create(:attachment, message: message, account: account)
        blob = attachment.file.blob
        
        # Mock da URL do ActiveStorage
        allow(blob).to receive(:url).and_return('https://storage.example.com/image.jpg?expires=123')
        
        expect(client_double).to receive(:send_media).with(
          channel.instance_name,
          hash_including(
            number: '5521999887766',
            mediatype: 'image',
            media: 'https://storage.example.com/image.jpg?expires=123'
          )
        ).and_return({ 'key' => { 'id' => 'media_msg_456' } })

        service = described_class.new(message: message)
        service.perform

        expect(message.reload.source_id).to eq('media_msg_456')
      end
    end

    context 'quando envia áudio via URL' do
      it 'usa send_whatsapp_audio com URL' do
        attachment = create(:attachment, message: message, account: account, file_type: :audio)
        blob = attachment.file.blob
        allow(blob).to receive(:content_type).and_return('audio/ogg')
        allow(blob).to receive(:url).and_return('https://storage.example.com/audio.ogg?expires=123')
        
        expect(client_double).to receive(:send_whatsapp_audio).with(
          channel.instance_name,
          hash_including(
            number: '5521999887766',
            audio: 'https://storage.example.com/audio.ogg?expires=123'
          )
        ).and_return({ 'key' => { 'id' => 'audio_msg_789' } })

        service = described_class.new(message: message)
        service.perform

        expect(message.reload.source_id).to eq('audio_msg_789')
      end
    end

    context 'quando envia documento' do
      it 'envia URL com nome de arquivo' do
        attachment = create(:attachment, message: message, account: account, file_type: :file)
        blob = attachment.file.blob
        allow(blob).to receive(:content_type).and_return('application/pdf')
        allow(blob).to receive(:filename).and_return(ActiveStorage::Filename.new('documento.pdf'))
        allow(blob).to receive(:url).and_return('https://storage.example.com/doc.pdf?expires=123')
        
        expect(client_double).to receive(:send_media).with(
          channel.instance_name,
          hash_including(
            number: '5521999887766',
            mediatype: 'document',
            media: 'https://storage.example.com/doc.pdf?expires=123',
            file_name: 'documento.pdf'
          )
        ).and_return({ 'key' => { 'id' => 'doc_msg_999' } })

        service = described_class.new(message: message)
        service.perform
      end
    end

    context 'quando URL falha (fallback para base64)' do
      it 'tenta base64 se URL não funcionar' do
        attachment = create(:attachment, message: message, account: account)
        blob = attachment.file.blob
        
        # Simular falha da URL
        allow(blob).to receive(:url).and_raise(StandardError, 'URL generation failed')
        
        # Deve tentar encode base64
        allow(blob).to receive(:open).and_yield(StringIO.new('fake_image_data'))
        
        expect(client_double).to receive(:send_media).and_return({ 'key' => { 'id' => 'fallback_msg' } })

        service = described_class.new(message: message)
        
        # Não deve dar erro, deve ter fallback
        expect { service.perform }.not_to raise_error
      end
    end
  end

  describe '#perform com erros' do
    it 'marca mensagem como failed se API retornar erro' do
      message = create(:message, conversation: conversation, message_type: :outgoing, content: 'Teste erro')
      
      allow(client_double).to receive(:send_text)
        .and_raise(Evolution::Client::Error, 'API Error: Instance not connected')

      service = described_class.new(message: message)
      
      expect { service.perform }.to raise_error(Evolution::Client::Error)
      expect(message.reload.status).to eq('failed')
    end
  end

  describe '#perform com quoted message (responder)' do
    let(:parent_message) do
      create(:message, conversation: conversation, message_type: :incoming, source_id: 'parent_msg_123')
    end
    
    it 'envia mensagem com quoted (resposta)' do
      message = create(:message,
                       conversation: conversation,
                       message_type: :outgoing,
                       content: 'Esta é uma resposta',
                       content_attributes: { in_reply_to: parent_message.id })
      
      expect(client_double).to receive(:send_text).with(
        channel.instance_name,
        hash_including(
          number: '5521999887766',
          text: 'Esta é uma resposta',
          quoted: hash_including('key' => hash_including('id' => 'parent_msg_123'))
        )
      ).and_return({ 'key' => { 'id' => 'reply_msg_456' } })

      service = described_class.new(message: message)
      service.perform
    end
  end

  describe 'ordenação de anexos' do
    it 'envia anexos na ordem correta (imagem > vídeo > áudio > documento)' do
      message = create(:message, conversation: conversation, message_type: :outgoing)
      
      # Criar anexos fora de ordem
      doc = create(:attachment, message: message, account: account, file_type: :file)
      img = create(:attachment, message: message, account: account, file_type: :image)
      vid = create(:attachment, message: message, account: account, file_type: :video)
      
      allow_any_instance_of(ActiveStorage::Blob).to receive(:url).and_return('http://example.com/file')
      
      # Deve enviar na ordem: imagem, vídeo, documento
      expect(client_double).to receive(:send_media).ordered.and_return({ 'key' => { 'id' => 'msg1' } })
      expect(client_double).to receive(:send_media).ordered.and_return({ 'key' => { 'id' => 'msg2' } })
      expect(client_double).to receive(:send_media).ordered.and_return({ 'key' => { 'id' => 'msg3' } })

      service = described_class.new(message: message)
      service.perform
    end
  end
end
