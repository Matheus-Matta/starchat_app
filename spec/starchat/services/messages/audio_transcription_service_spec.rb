require 'rails_helper'

RSpec.describe Messages::AudioTranscriptionService, type: :service do
  let(:account) { create(:account, audio_transcriptions: true) }
  let(:conversation) { create(:conversation, account: account) }
  let(:message) { create(:message, conversation: conversation, account: account) }
  let(:attachment) { message.attachments.create!(account: account, file_type: :audio) }
  let(:service) { described_class.new(attachment) }
  let(:message) { create(:message, account: account, conversation: conversation) }
  let(:attachment) { message.attachments.create!(account: account, file_type: :audio) }

  before do
    # Create required installation configs
    InstallationConfig.find_or_create_by!(name: 'COSMOS_OPEN_AI_API_KEY') { |config| config.value = 'test-api-key' }
    InstallationConfig.find_or_create_by!(name: 'COSMOS_OPEN_AI_MODEL') { |config| config.value = 'gpt-4o-mini' }

    # Mock usage limits for transcription to be available
    allow(account).to receive(:usage_limits).and_return(
      {
        agents: ChatwootApp.max_limit,
        inboxes: ChatwootApp.max_limit,
        cosmos: { responses: { current_available: 100 } }
      }
    )
  end

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

  describe '#transcribe_audio' do
    let(:service) { described_class.new(attachment) }
    let(:audio_api) { double('audio_api') } # rubocop:disable RSpec/VerifiedDoubles
    let(:audio_file_path) { Rails.root.join('tmp/audio_transcription_service_spec.mp3').to_s }

    before do
      File.binwrite(audio_file_path, 'audio')
      allow(service).to receive(:fetch_audio_file).and_return(audio_file_path)
      allow(service).to receive(:update_transcription)
      allow(service.client).to receive(:audio).and_return(audio_api)
    end

    after do
      FileUtils.rm_f(audio_file_path)
    end

    it 'uses the audio transcription feature model' do
      expect(audio_api).to receive(:transcribe).with(
        parameters: hash_including(model: 'gpt-4o-mini-transcribe', temperature: 0.0)
      ).and_return({ 'text' => 'Audio transcript' })

      expect(service.send(:transcribe_audio)).to eq('Audio transcript')
    end
  end
end
