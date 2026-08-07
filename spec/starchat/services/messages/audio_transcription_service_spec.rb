require 'rails_helper'

RSpec.describe Messages::AudioTranscriptionService, type: :service do
  let(:account) { create(:account, audio_transcriptions: true) }
  let(:conversation) { create(:conversation, account: account) }
  let(:message) { create(:message, conversation: conversation, account: account) }
  let(:attachment) { message.attachments.create!(account: account, file_type: :audio) }
  let(:service) { described_class.new(attachment) }

  describe '#perform' do
    context 'when the account has no provider configured' do
      it 'delegates to the whisper (local, free) engine by default' do
        whisper_service = instance_double(Messages::AudioTranscriptionWhisperService, perform: { success: true, transcriptions: 'hi' })
        allow(Messages::AudioTranscriptionWhisperService).to receive(:new).with(attachment).and_return(whisper_service)

        expect(service.perform).to eq({ success: true, transcriptions: 'hi' })
        expect(Messages::AudioTranscriptionWhisperService).to have_received(:new).with(attachment)
      end
    end

    context 'when the account provider is whisper' do
      before { account.update!(audio_transcription_provider: 'whisper') }

      it 'delegates to Messages::AudioTranscriptionWhisperService' do
        whisper_service = instance_double(Messages::AudioTranscriptionWhisperService, perform: { success: true, transcriptions: 'hi' })
        allow(Messages::AudioTranscriptionWhisperService).to receive(:new).with(attachment).and_return(whisper_service)

        expect(service.perform).to eq({ success: true, transcriptions: 'hi' })
      end
    end

    context 'when the account provider is openai' do
      before { account.update!(audio_transcription_provider: 'openai') }

      it 'delegates to Messages::AudioTranscriptionOpenaiService' do
        openai_service = instance_double(Messages::AudioTranscriptionOpenaiService, perform: { success: true, transcriptions: 'hi' })
        allow(Messages::AudioTranscriptionOpenaiService).to receive(:new).with(attachment).and_return(openai_service)

        expect(service.perform).to eq({ success: true, transcriptions: 'hi' })
      end
    end
  end
end
