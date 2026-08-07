require 'rails_helper'

RSpec.describe Starchat::Concerns::Attachment do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }

  describe '#enqueue_audio_transcription' do
    context 'when the audio attachment is on an incoming message' do
      let(:message) { create(:message, account: account, conversation: conversation, message_type: :incoming) }

      it 'enqueues Messages::AudioTranscriptionJob' do
        expect do
          message.attachments.create!(account: account, file_type: :audio)
        end.to have_enqueued_job(Messages::AudioTranscriptionJob)
      end
    end

    context 'when the audio attachment is on an outgoing message' do
      let(:message) { create(:message, account: account, conversation: conversation, message_type: :outgoing) }

      it 'does not enqueue Messages::AudioTranscriptionJob (only the manual context-menu action does)' do
        expect do
          message.attachments.create!(account: account, file_type: :audio)
        end.not_to have_enqueued_job(Messages::AudioTranscriptionJob)
      end
    end

    context 'when the attachment is not audio' do
      let(:message) { create(:message, account: account, conversation: conversation, message_type: :incoming) }

      it 'does not enqueue Messages::AudioTranscriptionJob' do
        expect do
          message.attachments.create!(account: account, file_type: :image)
        end.not_to have_enqueued_job(Messages::AudioTranscriptionJob)
      end
    end
  end
end
