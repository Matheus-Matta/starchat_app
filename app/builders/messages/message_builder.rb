class Messages::MessageBuilder
  include ::FileTypeHelper
  include ::EmailHelper
  include ::DataHelper

  attr_reader :message

  def initialize(user, conversation, params)
    @params = params
    @private = params[:private] || false
    @conversation = conversation
    @user = user
    @account = conversation.account
    @message_type = params[:message_type] || 'outgoing'
    @attachments = params[:attachments]
    @automation_rule = content_attributes&.dig(:automation_rule_id)
    return unless params.instance_of?(ActionController::Parameters)

    @in_reply_to = content_attributes&.dig(:in_reply_to)
    @items = content_attributes&.dig(:items)
  end

  def perform
    is_spam = check_anti_spam
    @message = @conversation.messages.build(message_params)
    if is_spam
      @message.status = :failed
      @message.content_attributes[:external_error] =
        I18n.t('conversations.messages.anti_spam_error', default: 'You are sending this message too frequently')
    end
    process_attachments
    process_emails
    # When the message has no quoted content, it will just be rendered as a regular message
    # The frontend is equipped to handle this case
    process_email_content
    validate_contact_inbox_linkage!
    @message.save!
    @message
  end

  private

  def validate_contact_inbox_linkage!
    return unless @account.require_contact_inbox_messaging
    return if @private
    return if @message_type == 'incoming'
    
    # Permitimos se já existe alguma conversa anterior ou se a conversa atual já tem mensagens inbound
    # Ou se o contato foi explicitamente vinculado (mas aqui a regra pede "real")
    # Checamos se existe pelo menos uma mensagem inbound no ContactInbox
    has_real_link = @conversation.contact_inbox.conversations.joins(:messages).where(messages: { message_type: :incoming }).exists?
    
    unless has_real_link
      raise CustomExceptions::InboxNotContactable, I18n.t('errors.messages.contact_not_linked')
    end
  end

  # Extracts content attributes from the given params.
  # - Converts ActionController::Parameters to a regular hash if needed.
  # - Attempts to parse a JSON string if content is a string.
  # - Returns an empty hash if content is not present, if there's a parsing error, or if it's an unexpected type.
  def content_attributes
    params = convert_to_hash(@params)
    content_attributes = params.fetch(:content_attributes, {})

    return safe_parse_json(content_attributes) if content_attributes.is_a?(String)
    return content_attributes if content_attributes.is_a?(Hash)

    {}
  end

  def process_attachments
    return if @attachments.blank?

    @attachments.each do |uploaded_attachment|
      attachment = @message.attachments.build(
        account_id: @message.account_id,
        file: uploaded_attachment
      )

      attachment.file_type = if uploaded_attachment.is_a?(String)
                               file_type_by_signed_id(
                                 uploaded_attachment
                               )
                             else
                               file_type(uploaded_attachment&.content_type)
                             end
    end
  end

  def process_emails
    return unless @conversation.inbox&.inbox_type == 'Email'

    cc_emails = process_email_string(@params[:cc_emails])
    bcc_emails = process_email_string(@params[:bcc_emails])
    to_emails = process_email_string(@params[:to_emails])

    all_email_addresses = cc_emails + bcc_emails + to_emails
    validate_email_addresses(all_email_addresses)

    @message.content_attributes[:cc_emails] = cc_emails
    @message.content_attributes[:bcc_emails] = bcc_emails
    @message.content_attributes[:to_emails] = to_emails
  end

  def process_email_content
    return unless should_process_email_content?

    @message.content_attributes ||= {}
    email_attributes = build_email_attributes
    @message.content_attributes[:email] = email_attributes
  end

  def process_email_string(email_string)
    return [] if email_string.blank?

    email_string.gsub(/\s+/, '').split(',')
  end

  def message_type
    raise StandardError, 'Incoming messages are only allowed in Api inboxes' if @conversation.inbox.channel_type != 'Channel::Api' && @message_type == 'incoming'

    @message_type
  end

  def sender
    %w[outgoing template].include?(message_type) ? (message_sender || @user) : @conversation.contact
  end

  def external_created_at
    @params[:external_created_at].present? ? { external_created_at: @params[:external_created_at] } : {}
  end

  def automation_rule_id
    @automation_rule.present? ? { content_attributes: { automation_rule_id: @automation_rule } } : {}
  end

  def campaign_id
    @params[:campaign_id].present? ? { additional_attributes: { campaign_id: @params[:campaign_id] } } : {}
  end

  def template_params
    @params[:template_params].present? ? { additional_attributes: { template_params: JSON.parse(@params[:template_params].to_json) } } : {}
  end

  def message_sender
    return if @params[:sender_type] != 'AgentBot'

    AgentBot.where(account_id: [nil, @conversation.account.id]).find_by(id: @params[:sender_id])
  end

  def status_param
    st = @params[:status]
    st.present? ? { status: st } : {}
  end

  def message_params
    {
      account_id: @conversation.account_id,
      inbox_id: @conversation.inbox_id,
      message_type: message_type,
      content: @params[:content],
      private: @private,
      sender: sender,
      content_type: @params[:content_type],
      items: @items,
      in_reply_to: @in_reply_to,
      echo_id: @params[:echo_id],
      source_id: @params[:source_id]
    }.merge(external_created_at).merge(automation_rule_id).merge(campaign_id).merge(template_params)
  end

  def email_inbox?
    @conversation.inbox&.inbox_type == 'Email'
  end

  def should_process_email_content?
    email_inbox? && !@private && @message.content.present?
  end

  def build_email_attributes
    email_attributes = ensure_indifferent_access(@message.content_attributes[:email] || {})
    normalized_content = normalize_email_body(@message.content)

    processed_content = process_liquid_in_email_body(normalized_content)

    email_attributes[:html_content] = if custom_email_content_provided?
                                        build_custom_html_content
                                      else
                                        build_html_content(processed_content)
                                      end

    email_attributes[:text_content] = build_text_content(processed_content)
    email_attributes
  end

  def build_html_content(normalized_content)
    html_content = ensure_indifferent_access(@message.content_attributes.dig(:email, :html_content) || {})
    rendered_html = render_email_html(normalized_content)
    html_content[:full] = rendered_html
    html_content[:reply] = rendered_html
    html_content
  end

  def build_text_content(normalized_content)
    text_content = ensure_indifferent_access(@message.content_attributes.dig(:email, :text_content) || {})
    text_content[:full] = normalized_content
    text_content[:reply] = normalized_content
    text_content
  end

  def custom_email_content_provided?
    @params[:email_html_content].present?
  end

  def build_custom_html_content
    html_content = ensure_indifferent_access(@message.content_attributes.dig(:email, :html_content) || {})
    html_content[:full] = @params[:email_html_content]
    html_content[:reply] = @params[:email_html_content]
    html_content
  end

  def process_liquid_in_email_body(content)
    return content if content.blank?
    return content unless should_process_liquid?

    modified_content = modified_liquid_content(content)
    template = Liquid::Template.parse(modified_content)
    template.render(drops_with_sender)
  rescue Liquid::Error
    content
  end

  def should_process_liquid?
    @message_type == 'outgoing' || @message_type == 'template'
  end

  def drops_with_sender
    message_drops(@conversation).merge({
                                         'agent' => UserDrop.new(sender)
                                       })
  end

  def check_anti_spam
    return false unless %w[outgoing template].include?(message_type)
    return false unless @conversation.inbox.anti_spam_enabled?

    current_sender = sender
    return false unless current_sender.is_a?(User)

    content = @params[:content].to_s.strip
    return false if content.blank?

    limit = @conversation.inbox.anti_spam_max_messages
    window_minutes = @conversation.inbox.anti_spam_time_window.to_i
    window_seconds = window_minutes * 60

    current_tokens = normalize_and_tokenize(content)
    return false if current_tokens.empty?

    history_key = "anti_spam_history:inbox:#{@conversation.inbox_id}:user:#{current_sender.id}"

    similar_count = 0
    is_spam = false

    $alfred.with do |redis|
      raw_history = redis.lrange(history_key, 0, 99)
      now = Time.now.to_i

      raw_history.each do |entry_json|
        entry = JSON.parse(entry_json)
        timestamp = entry['t']

        if (now - timestamp) <= window_seconds
          past_tokens = entry['s']
          similarity = calculate_token_similarity(current_tokens, past_tokens)

          similar_count += 1 if similarity >= 0.7
        end
      rescue JSON::ParserError
      end

      if (similar_count + 1) > limit
        is_spam = true
      else
        new_entry = { t: now, s: current_tokens }.to_json
        redis.multi do |multi|
          multi.lpush(history_key, new_entry)
          multi.ltrim(history_key, 0, 99)
          multi.expire(history_key, window_seconds + 300)
        end
      end

      Rails.logger.info "[Anti-Spam] Inbox: #{@conversation.inbox_id}, User: #{current_sender.id}, SimilarCount: #{similar_count}, Limit: #{limit}, Content: #{content.truncate(20)}, Spam: #{is_spam}"
    end

    is_spam
  end

  def normalize_and_tokenize(text)
    return [] if text.blank?

    normalized = text.to_s.downcase
    normalized = begin
      ActiveSupport::Inflector.transliterate(normalized)
    rescue StandardError
      normalized
    end
    normalized = normalized.gsub(/[^a-z0-9\s]/, '')
    normalized = normalized.gsub(/(.)\1{2,}/, '\1')
    tokens = normalized.split
    tokens = tokens.select { |t| t.length >= 2 } if normalized.length > 5
    tokens
  end

  def calculate_token_similarity(tokens1, tokens2)
    return 0.0 if tokens1.empty? || tokens2.empty?

    if tokens1.size == 1 && tokens2.size == 1
      s1 = tokens1[0]
      s2 = tokens2[0]
      max_len = [s1.length, s2.length].max
      return 0.0 if max_len.zero?

      dist = levenshtein_distance(s1, s2)
      similarity = 1.0 - (dist.to_f / max_len)
      return similarity
    end

    intersection_size = (tokens1 & tokens2).size
    min_size = [tokens1.size, tokens2.size].min
    return 0.0 if min_size.zero?

    intersection_size.to_f / min_size
  end

  def levenshtein_distance(s, t)
    m = s.length
    n = t.length
    return m if n.zero?
    return n if m.zero?

    d = Array.new(m+1) { Array.new(n+1) }

    (0..m).each { |i| d[i][0] = i }
    (0..n).each { |j| d[0][j] = j }
    (1..n).each do |j|
      (1..m).each do |i|
        cost = s[i-1] == t[j-1] ? 0 : 1
        d[i][j] = [d[i-1][j]+1, d[i][j-1]+1, d[i-1][j-1]+cost].min
      end
    end
    d[m][n]
  end
end
