class Conversations::ProtocolGenerator
  def initialize(conversation)
    @conversation = conversation
    @inbox        = conversation.inbox
    @policy       = @inbox.protocol_policy
    @contact      = conversation.contact
  end

  # Regra principal:
  # Se o contato já possui um protocolo ABERTO para esta política → reutiliza (encadeamento SAC).
  # Caso contrário → cria um novo protocolo com sequência e código únicos.
  def perform
    return unless @policy&.active?
    # Conversa já tem protocolo vinculado → nada a fazer
    return if @conversation.protocol_id.present?

    existing = Protocol.find_open_for_contact(@contact&.id, @policy.id) if @contact

    if existing
      attach_conversation_to_existing_protocol(existing)
    else
      create_new_protocol
    end

    send_welcome_message if @policy.welcome_message.present?
  end

  private

  # -----------------------------------------------------------------------
  # Reutilização: vincula a nova conversa ao protocolo aberto do contato.
  # Mantém o protocol_code / protocol_date / protocol_seq da conversa por
  # retrocompatibilidade com automações que leem esses campos.
  # -----------------------------------------------------------------------
  def attach_conversation_to_existing_protocol(protocol)
    @conversation.update!(
      protocol_id:         protocol.id,
      protocol_policy_id:  @policy.id,
      protocol_code:       protocol.code,
      protocol_date:       protocol.date,
      protocol_seq:        protocol.seq
    )
  end

  # -----------------------------------------------------------------------
  # Criação: gera novo código único, salva contador e cria registro Protocol.
  # Usa SELECT ... FOR UPDATE para evitar colisão em alta concorrência.
  # -----------------------------------------------------------------------
  def create_new_protocol
    date = Date.current

    ProtocolCounter.transaction do
      counter = find_or_initialize_counter(date)
      counter.lock!

      seq         = counter.last_seq.to_i + 1
      counter.last_seq = seq
      counter.save!

      code     = generate_code(seq, date)
      protocol = Protocol.create!(
        account:          @conversation.account,
        contact:          @contact,
        conversation:     @conversation,          # conversa de origem
        protocol_policy:  @policy,
        code:             code,
        seq:              seq,
        date:             date,
        status:           :open
      )

      @conversation.update!(
        protocol_id:         protocol.id,
        protocol_policy_id:  @policy.id,
        protocol_code:       code,
        protocol_date:       date,
        protocol_seq:        seq
      )
    end
  end

  # -----------------------------------------------------------------------
  # Mensagem automática: envia ao cliente com o código do protocolo.
  # Suporta variável {{protocol_code}} no template.
  # -----------------------------------------------------------------------
  def send_welcome_message
    code = @conversation.reload.protocol_code
    return if code.blank?

    content = @policy.welcome_message.gsub('{{protocol_code}}', code)
    params = { content: content, private: false }
    Messages::MessageBuilder.new(nil, @conversation, params).perform
  rescue StandardError => e
    Rails.logger.warn "[ProtocolGenerator] Falha ao enviar mensagem de boas-vindas: #{e.message}"
  end

  def find_or_initialize_counter(date)
    date_key = @policy.daily? ? date : nil
    begin
      ProtocolCounter.find_or_create_by!(protocol_policy_id: @policy.id, date: date_key)
    rescue ActiveRecord::RecordNotUnique
      retry
    end
  end

  def generate_code(seq, date)
    date_str = date.strftime('%y%m%d') # YYMMDD
    seq_str  = seq.to_s.rjust(@policy.seq_padding || 4, '0')
    "#{@policy.prefix}-#{date_str}-#{seq_str}"
  end
end
