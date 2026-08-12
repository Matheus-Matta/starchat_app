# Builds a broad, realistic dataset: one inbox of every channel type, contacts,
# conversations, messages and the surrounding configuration. Its purpose is to give data
# migrations something substantial to act on, so their effect can be observed instead of
# assumed.
#
#   bundle exec rake db:seed_full
#   SEED_LEGACY_STATE=true bundle exec rake db:seed_full   # also writes pre-migration shapes
#
# SEED_LEGACY_STATE writes the shapes the pending data migrations consume — feature flags
# in the JSONB overflow, installation config keys under their former names, and the stored
# feature defaults naming a renamed feature. Use it only on a database where those
# migrations have not run (or have been rolled back), otherwise it reintroduces state the
# application no longer understands.
namespace :db do
  desc 'Seed a full dataset: one inbox per channel type, conversations, messages and configuration'
  task seed_full: :environment do
    if Rails.env.production?
      puts 'Refusing to run in production.'
      exit 1
    end

    seeder = FullSeeder.new(legacy_state: ENV['SEED_LEGACY_STATE'] == 'true')
    seeder.perform
  end
end

class FullSeeder
  CHANNEL_BUILDERS = {
    'Website' => :web_widget,
    'Email' => :email,
    'API' => :api,
    'WhatsApp' => :whatsapp,
    'Evolution' => :evolution,
    'SMS' => :sms,
    'Twilio SMS' => :twilio_sms,
    'Telegram' => :telegram,
    'Line' => :line,
    'Facebook' => :facebook,
    'Instagram' => :instagram,
    'TikTok' => :tiktok,
    'X' => :twitter
  }.freeze

  def initialize(legacy_state: false)
    @legacy_state = legacy_state
    @created = Hash.new(0)
    @failures = []
  end

  def perform
    log "Seeding #{@legacy_state ? 'with pre-migration state' : 'current state'}"
    build_account
    build_users
    build_teams_and_labels
    build_inboxes
    build_contacts
    build_conversations
    build_configuration
    write_legacy_state if @legacy_state
    report
  end

  private

  def log(message)
    puts "  #{message}"
  end

  # Each section is isolated so one unsupported channel cannot abort the rest of the seed.
  def step(label)
    yield
    @created[label] += 1
  rescue StandardError => e
    @failures << "#{label}: #{e.class}: #{e.message}"
  end

  def build_account
    stamp = Time.now.to_i
    @account = Account.create!(name: "Seed Co #{stamp}", locale: 'en', domain: "seed-#{stamp}.test")
    @created['account'] += 1
    log "account ##{@account.id}"
  end

  def build_users
    stamp = @account.id
    @admin = create_user("Seed Admin #{stamp}", "seed-admin-#{stamp}@example.com", :administrator)
    @agents = (1..3).map { |i| create_user("Seed Agent #{stamp}-#{i}", "seed-agent-#{stamp}-#{i}@example.com", :agent) }
    log "1 admin + #{@agents.size} agents"
  end

  def create_user(name, email, role)
    user = User.new(name: name, email: email, password: 'Password1!')
    user.skip_confirmation!
    user.save!
    AccountUser.create!(account: @account, user: user, role: role)
    @created['user'] += 1
    user
  end

  def build_teams_and_labels
    @team = Team.create!(account: @account, name: "Support #{@account.id}", description: 'Front line')
    @agents.each { |agent| TeamMember.create!(team: @team, user: agent) }
    @created['team'] += 1

    %w[billing bug feature-request urgent].each_with_index do |title, index|
      Label.create!(account: @account, title: title, description: title.humanize,
                    color: %w[#FF6B6B #4ECDC4 #556270 #C7F464][index])
      @created['label'] += 1
    end

    %w[Hello Thanks Escalate].each do |title|
      CannedResponse.create!(account: @account, short_code: title.downcase, content: "#{title}, how can we help?")
      @created['canned_response'] += 1
    end
    log "team, #{@created['label']} labels, #{@created['canned_response']} canned responses"
  end

  def build_inboxes
    @inboxes = {}
    CHANNEL_BUILDERS.each do |name, kind|
      step("inbox:#{kind}") do
        channel = send("build_channel_#{kind}")
        inbox = Inbox.create!(account: @account, name: "#{name} Inbox", channel: channel)
        @agents.each { |agent| InboxMember.create!(inbox: inbox, user: agent) }
        InboxMember.create!(inbox: inbox, user: @admin)
        @inboxes[kind] = inbox
      end
    end
    log "#{@inboxes.size} of #{CHANNEL_BUILDERS.size} channel types"
    @failures.each { |f| log "  skipped #{f}" }
  end

  def build_channel_web_widget
    Channel::WebWidget.create!(account: @account, website_url: "https://seed-#{@account.id}.example.com",
                               widget_color: '#009CE0')
  end

  def build_channel_email
    Channel::Email.create!(account: @account, email: "care-#{@account.id}@example.com",
                           forward_to_email: "forward-#{@account.id}@example.com")
  end

  def build_channel_api
    Channel::Api.create!(account: @account, webhook_url: 'https://example.com/webhook')
  end

  def build_channel_whatsapp
    channel = Channel::Whatsapp.new(
      account: @account, phone_number: "+1555#{@account.id.to_s.rjust(6, '0')}", provider: 'whatsapp_cloud',
      provider_config: { 'api_key' => 'seed_key', 'phone_number_id' => 'seed_phone_id',
                         'business_account_id' => 'seed_waba_id' }
    )
    # The remote credential check and template sync would both reach out to Meta.
    channel.define_singleton_method(:validate_provider_config) { nil }
    channel.define_singleton_method(:sync_templates) { nil }
    channel.save!
    channel
  end

  def build_channel_evolution
    Channel::Evolution.create!(account: @account, instance_name: "evo-#{@account.id}",
                               api_key: SecureRandom.hex(16), provider_config: {})
  end

  def build_channel_sms
    Channel::Sms.create!(account: @account, phone_number: "+1556#{@account.id.to_s.rjust(6, '0')}",
                         provider_config: { 'api_key' => 'seed', 'api_secret' => 'seed' })
  end

  def build_channel_twilio_sms
    Channel::TwilioSms.create!(account: @account, account_sid: SecureRandom.uuid, auth_token: SecureRandom.uuid,
                               messaging_service_sid: "MG#{SecureRandom.hex(16)}", medium: :sms)
  end

  def build_channel_telegram
    channel = Channel::Telegram.new(account: @account, bot_token: SecureRandom.hex(16), bot_name: 'Seed Bot')
    channel.define_singleton_method(:setup_telegram_webhook) { nil }
    channel.save!(validate: false)
    channel
  end

  def build_channel_line
    Channel::Line.create!(account: @account, line_channel_id: SecureRandom.uuid,
                          line_channel_secret: SecureRandom.uuid, line_channel_token: SecureRandom.uuid)
  end

  def build_channel_facebook
    Channel::FacebookPage.create!(account: @account, page_access_token: SecureRandom.uuid,
                                  user_access_token: SecureRandom.uuid, page_id: SecureRandom.uuid)
  end

  def build_channel_instagram
    Channel::Instagram.create!(account: @account, access_token: SecureRandom.hex(32),
                               instagram_id: SecureRandom.hex(16), expires_at: 60.days.from_now)
  end

  def build_channel_tiktok
    Channel::Tiktok.create!(account: @account, business_id: SecureRandom.hex(16),
                            access_token: SecureRandom.hex(32), refresh_token: SecureRandom.hex(32),
                            expires_at: 1.day.from_now, refresh_token_expires_at: 30.days.from_now)
  end

  def build_channel_twitter
    Channel::TwitterProfile.create!(account: @account, profile_id: SecureRandom.hex(8),
                                    twitter_access_token: SecureRandom.hex(16),
                                    twitter_access_token_secret: SecureRandom.hex(16))
  end

  def build_contacts
    @contacts = (1..15).map do |i|
      Contact.create!(
        account: @account, name: "Seed Contact #{@account.id}-#{i}",
        email: "contact-#{@account.id}-#{i}@example.com",
        phone_number: "+1557#{format('%<n>06d', n: @account.id)}#{i.to_s.rjust(2, '0')}",
        additional_attributes: { 'city' => 'Sao Paulo', 'company_name' => "Company #{i}" }
      )
    end
    @created['contact'] = @contacts.size
    log "#{@contacts.size} contacts"
  end

  def build_conversations
    statuses = Conversation.statuses.keys
    priorities = [nil] + Conversation.priorities.keys

    @inboxes.each_value do |inbox|
      @contacts.first(4).each_with_index do |contact, index|
        step('conversation') do
          contact_inbox = ContactInbox.create!(
            contact: contact, inbox: inbox, source_id: source_id_for(inbox, contact)
          )
          conversation = Conversation.create!(
            account: @account, inbox: inbox, contact: contact, contact_inbox: contact_inbox,
            status: statuses[index % statuses.size],
            priority: priorities[index % priorities.size],
            assignee: (index.even? ? @agents.sample : nil),
            team: (index.zero? ? @team : nil),
            additional_attributes: { 'browser' => { 'browser_name' => 'chrome' } }
          )
          build_messages(conversation, contact)
        end
      end
    end
    log "#{@created['conversation']} conversations, #{@created['message']} messages"
  end

  # Several channels validate the shape of source_id — a phone number for the messaging
  # ones, a free identifier elsewhere — so generate one the inbox will accept.
  def source_id_for(inbox, contact)
    digits = "55#{format('%<n>09d', n: (inbox.id * 100) + contact.id)}"

    case inbox.channel_type
    when 'Channel::Whatsapp', 'Channel::Sms'
      digits
    when 'Channel::TwilioSms'
      "+#{digits}"
    when 'Channel::Email'
      contact.email
    else
      "#{inbox.id}-#{contact.id}-#{SecureRandom.hex(4)}"
    end
  end

  def build_messages(conversation, contact)
    common = { account: @account, inbox: conversation.inbox, conversation: conversation }

    Message.create!(**common, message_type: :incoming, sender: contact, content: 'Hi, I need help with my order.')
    Message.create!(**common, message_type: :outgoing, sender: @agents.sample, content: 'Happy to help — what is the order number?')
    Message.create!(**common, message_type: :incoming, sender: contact, content: 'It is #12345.')
    Message.create!(**common, message_type: :outgoing, sender: @agents.sample, private: true, content: 'Internal note: checking the warehouse.')
    Message.create!(**common, message_type: :activity, content: 'Conversation was marked resolved')
    @created['message'] += 5
  end

  def build_configuration
    # A real installation has its configs loaded; schema:load alone does not create them,
    # and the data migrations need them present to have anything to act on.
    GlobalConfig.clear_cache
    ConfigLoader.new.process
    @created['installation_config'] = InstallationConfig.count

    @account.enable_features!('conversation_unread_counts', 'unread_count_for_filters', 'assignment_v2')
    @account.update!(
      settings: { 'conversation_required_attributes' => [] },
      custom_attributes: { 'industry' => 'retail' },
      auto_resolve_duration: 720
    )

    %w[text list].each_with_index do |type, index|
      CustomAttributeDefinition.create!(
        account: @account, attribute_display_name: "Seed Attribute #{index + 1}",
        attribute_key: "seed_attribute_#{index + 1}", attribute_display_type: type,
        attribute_model: :conversation_attribute,
        attribute_values: (type == 'list' ? %w[one two three] : [])
      )
      @created['custom_attribute'] += 1
    end

    step('webhook') do
      Webhook.create!(account: @account, url: 'https://example.com/hooks/seed', webhook_type: :account_type)
    end
    log 'features, settings, custom attributes, webhook'
  end

  # Shapes the pending data migrations look for. Written only under SEED_LEGACY_STATE so a
  # normal seed never reintroduces state the application no longer understands.
  def write_legacy_state
    overflow = %w[advanced_assignment channel_ycloud audio_transcription]
    attributes = @account.internal_attributes || {}
    attributes['overflow_feature_flags'] = overflow
    @account.update!(internal_attributes: attributes)
    log "overflow_feature_flags: #{overflow.join(', ')}"

    {
      'CHATWOOT_INBOX_TOKEN' => 'seed-inbox-token',
      'CHATWOOT_INBOX_HMAC_KEY' => 'seed-hmac-key',
      'CHATWOOT_INSTANCE_ADMIN_EMAIL' => 'admin@seed.test'
    }.each do |name, value|
      # The rollback may already have restored the former name, so upsert rather than create.
      InstallationConfig.where(name: name.sub('CHATWOOT', 'STARCHATS')).destroy_all
      config = InstallationConfig.find_or_initialize_by(name: name)
      config.update!(value: value, locked: false)
      log "installation config under former name: #{name}"
    end

    defaults = InstallationConfig.find_by(name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS')
    return if defaults.blank?

    features = defaults.value
    features.each do |feature|
      next unless feature.is_a?(Hash) && feature['name'] == 'contact_starchats_support_team'

      feature['name'] = 'contact_chatwoot_support_team'
    end
    defaults.update!(value: features)
    log 'stored feature defaults name reverted to contact_chatwoot_support_team'
  end

  def report
    puts
    puts 'Seeded:'
    @created.sort.each { |label, count| puts format('  %-20<label>s %<count>d', label: label, count: count) }
    return if @failures.empty?

    puts
    puts 'Skipped:'
    @failures.each { |failure| puts "  #{failure}" }
  end
end
