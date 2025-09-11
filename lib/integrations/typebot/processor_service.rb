# lib/integrations/typebot/processor_service.rb
require 'uri'
require 'action_view'

class Integrations::Typebot::ProcessorService
  include ActionView::Helpers::SanitizeHelper

  DEFAULT_RESTART_KEYWORDS = %w[reiniciar reset restart iniciar começar novo /start /restart].freeze

  def initialize(hook:, event:)
    puts "[Typebot] Initializing ProcessorService with hook: #{hook.inspect}, event: #{event.inspect}"
    @hook  = hook
    @event = event.deep_symbolize_keys
  end

  def perform
    puts "[Typebot] perform called"
    return unless @event[:name].to_s == 'message_created'

    message = Message.find_by(id: @event.dig(:data, :message_id))
    puts "[Typebot] Fetched message: #{message.inspect}"
    return unless message.present?
    return unless message.incoming?
    return unless message.conversation.inbox_id == @hook.inbox_id

    settings = (@hook.settings || {}).stringify_keys
    puts "[Typebot] Settings: #{settings.inspect}"

    @text_format = settings['text_format'].to_s.presence || 'markdown'
    @text_format = 'markdown' unless %w[markdown richText].include?(@text_format)

    public_id = settings['public_id'].presence || extract_public_id(settings['share_url'])
    puts "[Typebot] public_id: #{public_id.inspect}"

    api_token = settings['api_token'].to_s
    puts "[Typebot] api_token: #{api_token.present? ? '[REDACTED]' : '(blank)'}"

    ttl = (settings['session_ttl_seconds'] || 86_400).to_i
    puts "[Typebot] ttl: #{ttl.inspect}"

    return if public_id.blank? || api_token.blank?

    base_url = settings['base_url'].presence || ENV.fetch('TYPEBOT_API_BASE', 'https://typebot.io')
    client   = ::Integrations::Typebot::Client.new(api_token: api_token, base_url: base_url)
    puts "[Typebot] Client initialized: #{client.inspect}"

    store = ::Integrations::Typebot::SessionStore.new
    puts "[Typebot] SessionStore initialized: #{store.inspect}"

    sess = store.get(message.conversation_id, @hook.id)
    puts "[Typebot] Session fetched: #{sess.inspect}"

    now        = Time.current
    user_txt   = sanitized_text(message.content).to_s
    rest_words = restart_keywords(settings).map(&:downcase)

    if sess.present? && truthy?(sess['is_ended'])
      ended_until = parse_time(sess['ended_expires_at'])
      still_block = ended_until.present? && ended_until > now

      if rest_words.any? { |w| user_txt.downcase.include?(w) }
        puts "[Typebot] Restart keyword detected while ended; resetting session tombstone"
        store.del(message.conversation_id, @hook.id)
        sess = nil
      elsif still_block
        puts "[Typebot] Session ended; ignoring input until #{ended_until.iso8601}"
        return
      else
        puts "[Typebot] Ended window expired; allowing restart"
        store.del(message.conversation_id, @hook.id)
        sess = nil
      end
    end

    if sess.blank?
      response = client.start_chat(public_id: public_id, payload: start_payload(message))
      puts "[Typebot] API response (start): #{response.inspect}"

      ended = ended_from_response?(response)
      session_data = {
        'session_id' => response['sessionId'],
        'result_id'  => response['resultId'],
        'is_ended'   => ended
      }

      if ended
        session_data['ended_at']         = now.iso8601
        session_data['ended_expires_at'] = (now + ttl).iso8601
      end

      store.set(message.conversation_id, @hook.id, session_data, ttl)
      puts "[Typebot] Session stored (start): #{session_data.inspect} (ttl=#{ttl})"

      publish_text_messages!(message.conversation, response)
      return
    end

    begin
      response = client.continue_chat(session_id: sess['session_id'], payload: continue_payload(message))
      puts "[Typebot] API response (continue): #{response.inspect}"
    rescue => e
      if e.message.include?('Session not found') || e.message.include?('NOT_FOUND')
        ended_at         = now
        ended_expires_at = now + ttl

        tombstone = (sess || {}).dup
        tombstone['session_id']        = nil
        tombstone['is_ended']          = true
        tombstone['ended_at']          = ended_at.iso8601
        tombstone['ended_expires_at']  = ended_expires_at.iso8601

        store.set(message.conversation_id, @hook.id, tombstone, ttl)
        puts "[Typebot] Session not found; marking as ended tombstone until #{ended_expires_at.iso8601} (ttl=#{ttl})"
        return
      else
        puts "[Typebot] continue_chat error: #{e.class} - #{e.message}"
        raise
      end
    end

    published_count = publish_text_messages!(message.conversation, response)
    puts "[Typebot] Published #{published_count} message(s) on continue"

    ended = ended_from_response?(response)

    session_data = store.get(message.conversation_id, @hook.id) || {}
    session_data['session_id'] = response['sessionId'] if response['sessionId'].present?
    session_data['result_id']  = response['resultId']  if response['resultId'].present?

    if ended
      session_data['is_ended']          = true
      session_data['ended_at']          = now.iso8601
      session_data['ended_expires_at']  = (now + ttl).iso8601
      store.set(message.conversation_id, @hook.id, session_data, ttl)
      puts "[Typebot] Flow ended; TTL refreshed and inputs will be ignored until #{session_data['ended_expires_at']}"
    elsif published_count > 0
      store.set(message.conversation_id, @hook.id, session_data, ttl)
      puts "[Typebot] Bot replied on continue; TTL refreshed (ttl=#{ttl})"
    else
      puts "[Typebot] No publishable reply on continue; TTL NOT refreshed"
    end
  rescue => e
    puts "[Typebot] Processor error: #{e.class} - #{e.message}"
    Rails.logger.error("[Typebot] Processor error: #{e.class} - #{e.message}")
  end

  private

  def truthy?(val)
    val == true || val.to_s == 'true' || val.to_s == '1'
  end

  def parse_time(val)
    return nil if val.blank?
    Time.zone.parse(val) rescue nil
  end

  def ended_from_response?(response)
    return true if response['isEnded'] == true

    input = response['input']
    return true if input.nil?

    t = input.is_a?(Hash) ? input['type'].to_s.downcase : input.to_s.downcase
    return true if %w[end finished completed none].include?(t)

    false
  end

  def extract_public_id(share_url)
    puts "[Typebot] extract_public_id called with share_url: #{share_url.inspect}"
    return if share_url.blank?
    id = URI.parse(share_url).path.split('/').last
    puts "[Typebot] Extracted public_id: #{id.inspect}"
    id
  rescue => e
    puts "[Typebot] Error extracting public_id: #{e.class} - #{e.message}"
    nil
  end

  def restart_keywords(settings)
    raw = settings['restart_keywords']
    case raw
    when String
      arr = raw.split(',').map { |s| s.to_s.strip }.reject(&:blank?)
      return arr.presence || DEFAULT_RESTART_KEYWORDS
    when Array
      arr = raw.map { |s| s.to_s.strip }.reject(&:blank?)
      return arr.presence || DEFAULT_RESTART_KEYWORDS
    else
      DEFAULT_RESTART_KEYWORDS
    end
  end

  def sanitized_text(str)
    puts "[Typebot] sanitized_text called with: #{str.inspect}"
    result = str.to_s.strip
    puts "[Typebot] sanitized_text result: #{result.inspect}"
    result
  end

  def start_payload(message)
    puts "[Typebot] start_payload called with message: #{message.inspect}"

    base_prefilled = prefilled_from_contact(message.conversation&.contact, message.conversation)
    prefilled = apply_variables_mapping(base_prefilled, (@hook.settings || {}).stringify_keys)

    payload = {
      message: { type: 'text', text: sanitized_text(message.content) },
      isStreamEnabled: false,
      isOnlyRegistering: false,
      textBubbleContentFormat: @text_format, # 'markdown' ou 'richText'
      prefilledVariables: prefilled
    }
    puts "[Typebot] start_payload prefilled keys: #{prefilled.keys.inspect}"
    puts "[Typebot] start_payload result: #{payload.inspect}"
    payload
  end

  def continue_payload(message)
    puts "[Typebot] continue_payload called with message: #{message.inspect}"
    payload = {
      message: { type: 'text', text: sanitized_text(message.content) },
      textBubbleContentFormat: @text_format
    }
    puts "[Typebot] continue_payload result: #{payload.inspect}"
    payload
  end

  def prefilled_from_contact(contact, conversation = nil)
    puts "[Typebot] prefilled_from_contact called with contact: #{contact.inspect}"
    return {} unless contact

    h = {}
    add = ->(key, val) do
      return if val.nil?
      val = val.to_s.strip
      return if val.empty?
      h[key] = val
    end

    add.call('contactId',         contact.id)
    add.call('contactName',       contact.name)
    add.call('contactEmail',      contact.email)
    add.call('contactPhone',      contact.phone_number)
    add.call('contactIdentifier', contact.identifier)
    add.call('contactType',       contact.contact_type)    if contact.respond_to?(:contact_type)
    add.call('contactCountryCode',contact.country_code)    if contact.respond_to?(:country_code)
    add.call('contactLocation',   contact.location)        if contact.respond_to?(:location)

    flatten_hash(contact.custom_attributes,     prefix: 'contactCustom').each { |k, v| add.call(k, v) }
    flatten_hash(contact.additional_attributes, prefix: 'contactAttr' ).each { |k, v| add.call(k, v) }

    if conversation
      add.call('conversationId',         conversation.id)
      add.call('conversationDisplayId',  conversation.display_id)
      add.call('conversationStatus',     conversation.status)
      flatten_hash(conversation.custom_attributes, prefix: 'conversationCustom').each { |k, v| add.call(k, v) }

      if (ci = conversation.contact_inbox)
        add.call('channelSourceId', ci.source_id)
      end

      add.call('inboxId',    conversation.inbox_id)
      add.call('inboxName',  conversation.inbox&.name)
      add.call('accountId',  conversation.account_id)
      add.call('accountName',conversation.account&.name)
    end

    puts "[Typebot] prefilled_from_contact result: #{h.inspect}"
    h
  end

  def flatten_hash(obj, prefix:)
    out = {}
    return out if obj.blank?

    walker = lambda do |val, key_path|
      key = ([prefix] + key_path).map.with_index do |part, idx|
        idx == 0 ? part : part.to_s.sub(/^\w/) { |c| c.upcase }
      end.join

      case val
      when Hash
        val.each { |k, v| walker.call(v, key_path + [k]) }
      when Array
        out[key] = val.map { |e| e.is_a?(Hash) ? e.to_json : e }.join(', ')
      else
        out[key] = val
      end
    end

    obj.each { |k, v| walker.call(v, [k]) }
    out
  end

  def publish_text_messages!(conversation, api_response)
    puts "[Typebot] publish_text_messages! called with conversation: #{conversation.inspect}, api_response: #{api_response.inspect}"

    count = 0

    Array(api_response['messages']).each do |m|
      puts "[Typebot] Processing message: #{m.inspect}"
      next unless m['type'] == 'text'

      text = m.dig('content', 'text') ||
             m.dig('content', 'markdown') ||
             m['message'] ||
             m.dig('content', 'richText')

      puts "[Typebot] Text to publish: #{text.inspect}"
      next if text.blank?

      plain =
        if text.is_a?(String)
          strip_tags(text.to_s).squish
        elsif text.is_a?(Array) # richText AST
          rich_text_to_plain(text)
        end

      puts "[Typebot] Plain text: #{plain.inspect}"
      next if plain.blank?

      conversation.messages.create!(
        message_type: :outgoing,
        content: plain,
        private: false,
        account_id: conversation.account_id,
        inbox_id: conversation.inbox_id
      )
      count += 1
      puts "[Typebot] Outgoing message created: #{plain.inspect}"
    end

    count
  end

  def rich_text_to_plain(rich)
    return '' if rich.blank?

    walker = lambda do |node|
      case node
      when String
        node
      when Hash
        return node['text'].to_s if node.key?('text')
        parts = Array(node['children']).map { |c| walker.call(c) }
        parts.join
      when Array
        node.map { |c| walker.call(c) }.join
      else
        ''
      end
    end

    lines = Array(rich).map { |n| walker.call(n) }.reject(&:blank?)
    lines.join("\n").strip
  end

  def apply_variables_mapping(src_hash, settings)
    map    = (settings['variables_map'] || {}).stringify_keys
    extras = (settings['extra_prefilled'] || {})
    out = {}

    src_hash.each do |k, v|
      targets = Array(map[k.to_s].presence || k)
      targets.each { |t| out[t] = v }
    end

    extras.each { |k, v| out[k] = v }
    out
  end
end
