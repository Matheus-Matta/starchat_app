require 'open3'

# Local, offline transcription engine (whisper.cpp). Free — no external API,
# gated by the standalone `audio_transcription` feature flag (not tied to
# Cosmos/OpenAI credits). Selected via account.audio_transcription_provider == 'whisper'.
#
# DISABLED for now (see config/features.yml) — the `whispercpp` gem isn't even in the
# Gemfile currently, so `require 'whisper'` is deferred to first real use (inside
# .whisper_context) instead of file load time. This lets Messages::AudioTranscriptionService
# reference this class (Zeitwerk autoload) without crashing app boot. Re-add the gem to
# the Gemfile before flipping the feature flag back on.
class Messages::AudioTranscriptionWhisperService
  include Integrations::LlmInstrumentation

  # "tiny" was tried first for speed but proved too inaccurate on real Portuguese
  # voice notes (non-English accuracy drops much more than English as model size
  # shrinks). ~2s per 10s of audio on CPU with AVX2 — override via
  # AUDIO_TRANSCRIPTION_MODEL if this still isn't accurate enough.
  WHISPER_MODEL = ENV.fetch('AUDIO_TRANSCRIPTION_MODEL', 'base').freeze
  # Local transcription has no API hard limit — this is just a safety cap so a
  # pathologically large audio file (e.g. a long call recording) doesn't tie up a
  # Sidekiq worker for minutes transcribing on CPU.
  MAX_AUDIO_BYTES = 25_000_000

  WHISPER_CONTEXT_MUTEX = Mutex.new
  private_constant :WHISPER_CONTEXT_MUTEX

  class << self
    # Loading the model is the expensive part (~500MB read + decode). Reused across
    # jobs in the same Sidekiq process instead of reloading it on every transcription.
    def whisper_context
      require 'whisper'
      @whisper_context || WHISPER_CONTEXT_MUTEX.synchronize { @whisper_context ||= Whisper::Context.new(WHISPER_MODEL) }
    end

    # Only needed so specs can swap in a stub between examples.
    def reset_whisper_context!
      @whisper_context = nil
    end
  end

  attr_reader :attachment, :message, :account

  def initialize(attachment)
    @attachment = attachment
    @message = attachment.message
    @account = message.account
  end

  def perform
    return { error: 'Transcription not available' } unless can_transcribe?
    return { error: 'Message not found' } if message.blank?
    return { error: 'Audio too large for Whisper' } if audio_too_large?

    transcriptions = transcribe_audio
    Rails.logger.info "Audio transcription successful: #{transcriptions}"
    { success: true, transcriptions: transcriptions }
  rescue StandardError => e
    Rails.logger.warn("Skipping audio transcription: #{e.class} #{e.message}")
    { error: 'Local audio transcription failed' }
  end

  private

  def can_transcribe?
    return false unless account.feature_enabled?('audio_transcription')

    account.audio_transcriptions.present?
  end

  def audio_too_large?
    blob = attachment.file&.blob
    return false unless blob

    blob.byte_size > MAX_AUDIO_BYTES
  end

  def fetch_audio_file
    blob = attachment.file.blob
    temp_dir = Rails.root.join('tmp/uploads/audio-transcriptions')
    FileUtils.mkdir_p(temp_dir)
    temp_file_name = "#{blob.key}-#{blob.filename}"

    if blob.filename.extension_without_delimiter.blank?
      extension = extension_from_content_type(blob.content_type)
      temp_file_name = "#{temp_file_name}.#{extension}" if extension.present?
    end

    temp_file_path = File.join(temp_dir, temp_file_name)

    File.open(temp_file_path, 'wb') do |file|
      blob.open do |blob_file|
        IO.copy_stream(blob_file, file)
      end
    end

    temp_file_path
  end

  def transcribe_audio
    transcribed_text = attachment.meta&.[]('transcribed_text') || ''
    return transcribed_text if transcribed_text.present?

    source_path = fetch_audio_file
    wav_path = "#{source_path}.16k.wav"
    convert_to_wav!(source_path, wav_path)

    transcribed_text = instrument_audio_transcription(instrumentation_params(wav_path)) do
      transcribe_wav(wav_path)
    end

    update_transcription(transcribed_text)
    transcribed_text
  ensure
    FileUtils.rm_f(source_path) if source_path.present?
    FileUtils.rm_f(wav_path) if wav_path.present?
  end

  # whisper.cpp only reads mono 16kHz PCM WAV files, so incoming formats
  # (ogg/opus, m4a, mp3, ...) are normalised with ffmpeg first. Uses an argv
  # array (no shell interpolation) to avoid shell-injection via filenames.
  def convert_to_wav!(source_path, wav_path)
    _stdout, stderr, status = Open3.capture3(
      'ffmpeg', '-y', '-i', source_path, '-ar', '16000', '-ac', '1', '-c:a', 'pcm_s16le', wav_path
    )
    raise "ffmpeg conversion failed: #{stderr}" unless status.success?
  end

  def transcribe_wav(wav_path)
    # .whisper_context is called first (not inline below) because it's what lazily
    # requires "whisper" — Whisper::Params wouldn't resolve otherwise.
    context = self.class.whisper_context
    # Hinting the account's language avoids auto-detect mistakes on short/noisy
    # clips (e.g. a 2s "ok" getting tagged as the wrong language). Falls back to
    # auto-detect only if the account has no locale set.
    params = Whisper::Params.new(language: transcription_language, translate: false, print_timestamps: false)

    context.transcribe(wav_path, params).each_segment.map(&:text).join.strip
  end

  # whisper.cpp expects bare ISO-639-1 codes ("pt", "en"); account.locale can be
  # region-qualified ("pt_BR"), so only the language part before "_" is kept.
  def transcription_language
    account.locale.to_s.split('_').first.presence || 'auto'
  end

  def instrumentation_params(file_path)
    {
      span_name: 'llm.messages.audio_transcription',
      model: WHISPER_MODEL,
      account_id: account&.id,
      feature_name: 'audio_transcription',
      file_path: file_path
    }
  end

  def update_transcription(transcribed_text)
    return if transcribed_text.blank?

    attachment.update!(meta: { transcribed_text: transcribed_text })
    message.reload.send_update_event

    return unless ChatwootApp.advanced_search_allowed?

    message.reindex
  end

  def extension_from_content_type(content_type)
    subtype = content_type.to_s.downcase.split(';').first.to_s.split('/').last.to_s
    return if subtype.blank?

    {
      'x-m4a' => 'm4a',
      'x-wav' => 'wav',
      'x-mp3' => 'mp3'
    }.fetch(subtype, subtype)
  end
end
