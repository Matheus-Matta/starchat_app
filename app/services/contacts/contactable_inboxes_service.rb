class Contacts::ContactableInboxesService
  pattr_initialize [:contact!, :only_existing]

  def get
    # Se foi solicitado especificamente apenas os vínculos existentes (usado na tela de detalhes)
    if only_existing
      get_all_existing_contact_inboxes
    # Se a conta exige vínculo real para NOVAS conversas (usado no modal de nova conversa)
    elsif contact.account.require_contact_inbox_messaging
      get_existing_links_with_conversations
    else
      # Comportamento padrão: Todas as inboxes onde é possível iniciar uma nova conversa
      get_all_contactable_inboxes
    end
  end

  private

  # Retorna TODOS os vínculos existentes, com ou sem conversa (usado para exibir vínculos na UI)
  def get_all_existing_contact_inboxes
    contact.contact_inboxes.map do |contact_inbox|
      { source_id: contact_inbox.source_id, inbox: contact_inbox.inbox }
    end
  end

  # Retorna apenas vínculos que REALMENTE possuem conversas (evita vínculos fantasmas)
  def get_existing_links_with_conversations
    contact.contact_inboxes.filter_map do |contact_inbox|
      # Se não tem conversa, é um vínculo fantasma (exceto se a config da conta permitir, mas aqui focamos no "real")
      next unless contact_inbox.conversations.exists?

      { source_id: contact_inbox.source_id, inbox: contact_inbox.inbox }
    end
  end

  # Retorna todas as inboxes onde é possível contactar (mesmo sem vínculo existente)
  def get_all_contactable_inboxes
    # Se a conta exige vínculo para enviar mensagem, talvez devêssemos filtrar aqui?
    # Por enquanto mantemos o padrão de Chatwoot: todas as compatíveis
    account = contact.account
    account.inboxes.filter_map { |inbox| get_contactable_inbox(inbox) }
  end

  def get_contactable_inbox(inbox)
    case inbox.channel_type
    when 'Channel::TwilioSms'
      twilio_contactable_inbox(inbox)
    when 'Channel::Whatsapp'
      whatsapp_contactable_inbox(inbox)
    when 'Channel::Evolution'
      evolution_contactable_inbox(inbox)
    when 'Channel::Sms'
      sms_contactable_inbox(inbox)
    when 'Channel::Email'
      email_contactable_inbox(inbox)
    when 'Channel::Api'
      api_contactable_inbox(inbox)
    when 'Channel::WebWidget'
      website_contactable_inbox(inbox)
    when 'Channel::Voice'
      voice_contactable_inbox(inbox)
    end
  end

  def voice_contactable_inbox(inbox)
    return if @contact.phone_number.blank?

    { source_id: @contact.phone_number, inbox: inbox }
  end

  # Métodos para obter inboxes contactáveis (todas compatíveis)
  def website_contactable_inbox(inbox)
    latest_contact_inbox = inbox.contact_inboxes.where(contact: @contact).last
    return unless latest_contact_inbox
    # Para WebWidget,Chatwoot geralmente impede iniciar nova conversa se já existe uma ativa
    return if latest_contact_inbox.conversations.present?

    { source_id: latest_contact_inbox.source_id, inbox: inbox }
  end

  def api_contactable_inbox(inbox)
    latest_contact_inbox = inbox.contact_inboxes.where(contact: @contact).last
    source_id = latest_contact_inbox&.source_id || SecureRandom.uuid

    { source_id: source_id, inbox: inbox }
  end

  def email_contactable_inbox(inbox)
    return if @contact.email.blank?

    { source_id: @contact.email, inbox: inbox }
  end

  def whatsapp_contactable_inbox(inbox)
    return if @contact.phone_number.blank?

    # Remove the plus since thats the format 360 dialog uses
    { source_id: @contact.phone_number.delete('+'), inbox: inbox }
  end

  def evolution_contactable_inbox(inbox)
    return if @contact.phone_number.blank?

    { source_id: @contact.phone_number.delete('+'), inbox: inbox }
  end

  def sms_contactable_inbox(inbox)
    return if @contact.phone_number.blank?

    { source_id: @contact.phone_number, inbox: inbox }
  end

  def twilio_contactable_inbox(inbox)
    return if @contact.phone_number.blank?

    # Suporta SMS, WhatsApp e Voz no Twilio
    case inbox.channel.medium
    when 'whatsapp'
      { source_id: "whatsapp:#{@contact.phone_number}", inbox: inbox }
    else
      # Default para sms, voice e outros meios que usem o phone_number diretamente
      { source_id: @contact.phone_number, inbox: inbox }
    end
  end
end
