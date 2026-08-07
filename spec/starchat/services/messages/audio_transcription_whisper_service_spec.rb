require 'rails_helper'

RSpec.describe Messages::AudioTranscriptionWhisperService, type: :service do
  let(:account) { create(:account, audio_transcriptions: true) }
  let(:conversation) { create(:conversation, account: account) }
  let(:message) { create(:message, conversation: conversation) }
  let(:attachment) { message.attachments.create!(account: account, file_type: :audio) }

  describe '#perform' do
    let(:service) { described_class.new(attachment) }

    context 'when audio_transcription feature is not enabled' do
      before do
        account.disable_features!('audio_transcription')
      end

      it 'returns transcription not available' do
        expect(service.perform).to eq({ error: 'Transcription not available' })
      end
    end

    context 'when transcription is successful' do
      before do
        # Mock can_transcribe? to return true and transcribe_audio method
        allow(service).to receive(:can_transcribe?).and_return(true)
        allow(service).to receive(:transcribe_audio).and_return('Hello world transcription')
      end

      it 'returns successful transcription' do
        result = service.perform
        expect(result).to eq({ success: true, transcriptions: 'Hello world transcription' })
      end
    end

    context 'when audio transcriptions are disabled' do
      before do
        account.update!(audio_transcriptions: false)
      end

      it 'returns error for transcription not available' do
        result = service.perform
        expect(result).to eq({ error: 'Transcription not available' })
      end
    end

    context 'when attachment already has transcribed text' do
      before do
        attachment.update!(meta: { transcribed_text: 'Existing transcription' })
        allow(service).to receive(:can_transcribe?).and_return(true)
      end

      it 'returns existing transcription without calling API' do
        result = service.perform
        expect(result).to eq({ success: true, transcriptions: 'Existing transcription' })
      end
    end

    context 'when the audio exceeds Whisper byte limit' do
      before do
        attachment.file.attach(
          io: File.open(Rails.public_path.join('audio/widget/ding.mp3')),
          filename: 'large.mp3',
          content_type: 'audio/mpeg'
        )
        allow(service).to receive(:can_transcribe?).and_return(true)
        allow(attachment.file.blob).to receive(:byte_size).and_return(described_class::MAX_AUDIO_BYTES + 1)
      end

      it 'returns an error without calling Whisper' do
        expect(service).not_to receive(:transcribe_audio)
        expect(service.perform).to eq({ error: 'Audio too large for Whisper' })
      end
    end
  end

  describe '#fetch_audio_file' do
    let(:service) { described_class.new(attachment) }

    before do
      attachment.file.attach(
        io: File.open(Rails.public_path.join('audio/widget/ding.mp3')),
        filename: 'speech',
        content_type: 'audio/mpeg'
      )
    end

    it 'adds extension from content type when filename has no extension' do
      temp_file_path = service.send(:fetch_audio_file)

      expect(File.extname(temp_file_path)).to eq('.mpeg')
    ensure
      FileUtils.rm_f(temp_file_path) if temp_file_path.present?
    end
  end

  # SKIPPED: audio_transcription is disabled for now (see config/features.yml) and the
  # whispercpp gem was removed from the Gemfile along with it, so Whisper::Context /
  # Whisper::Segment aren't defined constants here. Re-enable once the gem is back.
  describe '#transcribe_audio', skip: 'whispercpp gem not installed while audio_transcription is disabled' do
    let(:service) { described_class.new(attachment) }
    let(:segment) { instance_double(Whisper::Segment, text: 'Hello world') }
    let(:whisper_context) { instance_double(Whisper::Context) }
    let(:successful_status) { instance_double(Process::Status, success?: true) }

    before do
      # The context is memoized per-process (see .whisper_context), so each example
      # needs a clean slate for the Whisper::Context.new stub below to take effect.
      described_class.reset_whisper_context!
      attachment.file.attach(
        io: File.open(Rails.public_path.join('audio/widget/ding.mp3')),
        filename: 'speech.mp3',
        content_type: 'audio/mpeg'
      )
      allow(Open3).to receive(:capture3).and_return(['', '', successful_status])
      allow(Whisper::Context).to receive(:new).and_return(whisper_context)
      allow(whisper_context).to receive(:transcribe).and_return(whisper_context)
      allow(whisper_context).to receive(:each_segment).and_return([segment])
    end

    after { described_class.reset_whisper_context! }

    it 'converts the audio with ffmpeg and transcribes it locally with whisper.cpp' do
      result = service.send(:transcribe_audio)

      expect(Open3).to have_received(:capture3).with(
        'ffmpeg', '-y', '-i', anything, '-ar', '16000', '-ac', '1', '-c:a', 'pcm_s16le', anything
      )
      expect(Whisper::Context).to have_received(:new).with(described_class::WHISPER_MODEL)
      expect(result).to eq('Hello world')
      expect(attachment.reload.meta['transcribed_text']).to eq('Hello world')
    end

    context 'when ffmpeg conversion fails' do
      let(:successful_status) { instance_double(Process::Status, success?: false) }

      before do
        allow(Open3).to receive(:capture3).and_return(['', 'boom', successful_status])
      end

      it 'raises so #perform can report the failure' do
        expect { service.send(:transcribe_audio) }.to raise_error(/ffmpeg conversion failed/)
      end
    end
  end
end
