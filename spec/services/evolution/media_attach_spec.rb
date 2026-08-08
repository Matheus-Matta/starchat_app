# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Evolution::MediaAttach do
  # Classe de teste que inclui o módulo
  let(:test_class) do
    Class.new do
      include Evolution::MediaAttach
      include Evolution::DownloadForBase64
      include FileTypeHelper

      # Mock do método download_for_whatsapp_enc
      def download_for_whatsapp_enc(url:, media_key:, media_type:, filename:, content_type:, headers:, identify:)
        # Simular criação de blob
        ActiveStorage::Blob.create_and_upload!(
          io: StringIO.new('encrypted_data_from_url'),
          filename: filename,
          content_type: content_type
        )
      end
    end.new
  end

  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, inbox: inbox, account: account) }
  let(:message) { create(:message, conversation: conversation, account: account) }

  describe '#attach_from_payload!' do
    context 'quando payload tem URL + mediaKey (PRIORITÁRIO)' do
      let(:payload) do
        {
          'message' => {
            'imageMessage' => {
              'url' => 'https://mmg.whatsapp.net/v/t62.7118-24/file.enc',
              'mediaKey' => 'W8qE5TxYZ9fQ==',
              'mimetype' => 'image/jpeg',
              'directPath' => '/v/t62.7118-24/file.enc'
            }
          }
        }
      end

      it 'prioriza download via URL (.enc) ANTES de tentar base64' do
        expect(test_class).to receive(:download_for_whatsapp_enc).with(
          hash_including(
            url: 'https://mmg.whatsapp.net/v/t62.7118-24/file.enc',
            media_key: 'W8qE5TxYZ9fQ=='
          )
        ).and_call_original

        expect(test_class).not_to receive(:download_for_base64)

        result = test_class.attach_from_payload!(message, payload)

        expect(result).to be true
        expect(message.attachments.size).to eq(1)
      end

      it 'loga que está processando via URL' do
        message # force lazy let to create account/inbox/conversation/message before logger expectation
        allow(Rails.logger).to receive(:info)
        expect(Rails.logger).to receive(:info).with(/Trying \.enc download/)

        test_class.attach_from_payload!(message, payload)
      end
    end

    context 'quando payload tem base64 (FALLBACK)' do
      let(:payload) do
        {
          'message' => {
            'imageMessage' => {
              'base64' => 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
              'mimetype' => 'image/png'
            }
          }
        }
      end

      it 'usa base64 se não houver URL + mediaKey' do
        expect(test_class).to receive(:download_for_base64).with(
          String,
          hash_including(content_type: 'image/png')
        ).and_call_original

        expect(test_class).not_to receive(:download_for_whatsapp_enc)

        result = test_class.attach_from_payload!(message, payload)

        expect(result).to be true
        expect(message.attachments.size).to eq(1)
      end

      it 'loga que está fazendo fallback para base64' do
        message # force lazy let to create account/inbox/conversation/message before logger expectation
        allow(Rails.logger).to receive(:info)
        expect(Rails.logger).to receive(:info).with(/Found Base64\. Processing/)

        test_class.attach_from_payload!(message, payload)
      end
    end

    context 'quando payload tem AMBOS (URL + base64)' do
      let(:payload) do
        {
          'message' => {
            'imageMessage' => {
              'url' => 'https://mmg.whatsapp.net/v/t62.7118-24/file.enc',
              'mediaKey' => 'MediaKey123==',
              'base64' => 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
              'mimetype' => 'image/jpeg'
            }
          }
        }
      end

      it 'PRIORIZA URL ignorando base64 (mais eficiente)' do
        expect(test_class).to receive(:download_for_whatsapp_enc).and_call_original
        expect(test_class).not_to receive(:download_for_base64)

        result = test_class.attach_from_payload!(message, payload)
        expect(result).to be true
      end
    end

    context 'quando não tem mídia válida' do
      let(:payload) do
        {
          'message' => {
            'conversation' => 'Apenas texto'
          }
        }
      end

      it 'retorna false' do
        result = test_class.attach_from_payload!(message, payload)
        expect(result).to be false
        expect(message.attachments.size).to eq(0)
      end
    end

    context 'quando payload tem URL mas sem mediaKey' do
      let(:payload) do
        {
          'message' => {
            'imageMessage' => {
              'url' => 'https://mmg.whatsapp.net/file.enc',
              'mimetype' => 'image/jpeg'
              # SEM mediaKey!
            }
          }
        }
      end

      it 'pula URL e tenta base64 se disponível' do
        expect(test_class).not_to receive(:download_for_whatsapp_enc)
        allow(test_class).to receive(:try_simple_download).and_return(false)

        # Como não tem base64 e download simples retorna false, deve retornar false
        result = test_class.attach_from_payload!(message, payload)
        expect(result).to be false
      end
    end

    context 'diferentes tipos de mídia' do
      it 'processa vídeo via URL' do
        payload = {
          'message' => {
            'videoMessage' => {
              'url' => 'https://mmg.whatsapp.net/video.enc',
              'mediaKey' => 'VideoKey==',
              'mimetype' => 'video/mp4'
            }
          }
        }

        result = test_class.attach_from_payload!(message, payload)
        expect(result).to be true
      end

      it 'processa áudio via URL' do
        payload = {
          'message' => {
            'audioMessage' => {
              'url' => 'https://mmg.whatsapp.net/audio.enc',
              'mediaKey' => 'AudioKey==',
              'mimetype' => 'audio/ogg'
            }
          }
        }

        result = test_class.attach_from_payload!(message, payload)
        expect(result).to be true
      end

      it 'processa documento via URL' do
        payload = {
          'message' => {
            'documentMessage' => {
              'url' => 'https://mmg.whatsapp.net/doc.enc',
              'mediaKey' => 'DocKey==',
              'mimetype' => 'application/pdf',
              'fileName' => 'documento.pdf'
            }
          }
        }

        result = test_class.attach_from_payload!(message, payload)
        expect(result).to be true
      end
    end

    context 'tratamento de erros' do
      let(:payload) do
        {
          'message' => {
            'imageMessage' => {
              'url' => 'https://invalid-url',
              'mediaKey' => 'Key==',
              'mimetype' => 'image/jpeg'
            }
          }
        }
      end

      it 'captura erro e retorna false' do
        allow(test_class).to receive(:download_for_whatsapp_enc).and_raise(StandardError, 'Download failed')

        expect(Rails.logger).to receive(:warn).with(/erro: StandardError Download failed/)

        result = test_class.attach_from_payload!(message, payload)
        expect(result).to be false
      end
    end

    context 'extração de base64 de diferentes locais do payload' do
      it 'encontra base64 em data field' do
        payload = {
          'message' => {
            'imageMessage' => {
              'data' => 'BASE64_STRING_HERE',
              'mimetype' => 'image/png'
            }
          }
        }

        expect(test_class).to receive(:download_for_base64).with('BASE64_STRING_HERE', anything).and_call_original

        test_class.attach_from_payload!(message, payload)
      end

      it 'encontra base64 em jpegThumbnail' do
        payload = {
          'message' => {
            'imageMessage' => {
              'jpegThumbnail' => 'THUMBNAIL_BASE64',
              'mimetype' => 'image/jpeg'
            }
          }
        }

        # Como não tem URL, deve usar o thumbnail
        result = test_class.attach_from_payload!(message, payload)
        expect(result).to be true
      end
    end
  end

  describe '#suggested_filename_from_payload_like_wa' do
    it 'gera nome de arquivo com extensão correta para PNG' do
      filename = test_class.send(:suggested_filename_from_payload_like_wa, :image, 'image/png')
      expect(filename).to match(/file-[a-f0-9]{8}\.png/)
    end

    it 'gera nome de arquivo com extensão correta para MP4' do
      filename = test_class.send(:suggested_filename_from_payload_like_wa, :video, 'video/mp4')
      expect(filename).to match(/file-[a-f0-9]{8}\.mp4/)
    end

    it 'gera nome de arquivo com extensão correta para áudio OGG' do
      filename = test_class.send(:suggested_filename_from_payload_like_wa, :audio, 'audio/ogg')
      expect(filename).to match(/file-[a-f0-9]{8}\.ogg/)
    end
  end
end
