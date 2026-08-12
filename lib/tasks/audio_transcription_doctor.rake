# Reports which gate is stopping audio transcription for an account. Every check below
# mirrors a real early-return in the transcription path, in the order the code hits them.
#
#   ACCOUNT_ID=1 bundle exec rake audio_transcription:doctor
namespace :audio_transcription do
  desc 'Diagnose why audio transcription is not running for an account'
  task doctor: :environment do
    account_id = ENV.fetch('ACCOUNT_ID', nil)
    if account_id.blank?
      puts 'Usage: ACCOUNT_ID=<id> bundle exec rake audio_transcription:doctor'
      exit 1
    end

    account = Account.find(account_id)
    problems = []

    puts "Account ##{account.id} — #{account.name}"
    puts

    key = InstallationConfig.find_by(name: 'COSMOS_OPEN_AI_API_KEY')&.value
    report('OpenAI API key configured', key.present?, 'set COSMOS_OPEN_AI_API_KEY in super admin settings', problems)

    provider = account.audio_transcription_provider
    report("provider is 'openai' (currently #{provider.inspect})", provider == 'openai',
           "account.update!(audio_transcription_provider: 'openai') — blank falls back to local whisper", problems)

    report('cosmos_integration feature enabled', account.feature_enabled?('cosmos_integration'),
           "account.enable_features!('cosmos_integration') — this is the flag the OpenAI path checks", problems)

    report('audio_transcriptions setting on', account.audio_transcriptions.present?,
           'account.update!(audio_transcriptions: true)', problems)

    available = account.usage_limits.dig(:cosmos, :responses, :current_available).to_i
    report("cosmos response credits available (#{available})", available.positive?,
           'reset usage with account.reset_response_usage', problems)

    puts
    if problems.empty?
      puts 'Every gate is open. If transcription still does not run, check that the message is'
      puts 'incoming (outgoing audio transcribes only on demand), that the file is under 25 MB,'
      puts 'and that the low queue is being worked — the job runs as Messages::AudioTranscriptionJob.'
    else
      puts "Blocked by #{problems.size} #{'gate'.pluralize(problems.size)}:"
      problems.each { |p| puts "  - #{p}" }
    end
  end

  def report(label, ok, remedy, problems)
    puts "  #{ok ? '[ok]  ' : '[FAIL]'} #{label}"
    problems << "#{label} -> #{remedy}" unless ok
  end
end
