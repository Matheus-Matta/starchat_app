# Picks the transcription engine configured for the account and delegates to it.
# Keeps a stable public interface (`.new(attachment).perform`) for
# Messages::AudioTranscriptionJob regardless of which engine ends up running.
class Messages::AudioTranscriptionService
  PROVIDERS = {
    'openai' => Messages::AudioTranscriptionOpenaiService,
    'whisper' => Messages::AudioTranscriptionWhisperService
  }.freeze
  DEFAULT_PROVIDER = 'whisper'.freeze

  def initialize(attachment)
    @attachment = attachment
  end

  def perform
    provider_service.perform
  end

  private

  def provider_service
    provider_class = PROVIDERS.fetch(account.audio_transcription_provider, PROVIDERS.fetch(DEFAULT_PROVIDER))
    provider_class.new(@attachment)
  end

  def account
    @attachment.message.account
  end
end
