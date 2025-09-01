module Evolution
  module WaUtils
    module_function

    # --------- básicos ---------
    def phone_jid?(jid)
      jid.to_s.end_with?('@s.whatsapp.net')
    end

    # "5521999:64@s.whatsapp.net" -> "+5521999..."
    def e164_from_jid(jid)
      raw    = jid.to_s.split('@').first.to_s.split(':').first
      digits = raw.gsub(/\D/, '')
      return nil if digits.length < 8 || digits.length > 15
      "+#{digits}"
    end

    def profile_pic_url(row)
      h = row.respond_to?(:with_indifferent_access) ? row.with_indifferent_access : row
      (h[:profilePicUrl].presence || h[:profile_pic_url].presence).to_s.presence
    end

    def extract_remote_jid(payload)
      h = payload.respond_to?(:with_indifferent_access) ? payload.with_indifferent_access : payload
      h[:remoteJid].presence || h.dig(:key, :remoteJid).presence
    end

    def extract_push_name(payload)
      h = payload.respond_to?(:with_indifferent_access) ? payload.with_indifferent_access : payload
      h[:pushName].presence || h[:push_name].presence
    end

    # --------- Contact / Conversation ---------

    # ÚNICO método oficial: cria/obtém Contact e ContactInbox
    # Retorna [contact_inbox, contact]
    def find_or_create_contact_inbox!(account:, inbox:, remote_jid:, push_name: nil, profile_pic: nil)
      raise ArgumentError, 'remote_jid ausente' if remote_jid.blank?

      phone_e164 = e164_from_jid(remote_jid)
      raise ArgumentError, "remote_jid inválido para contato: #{remote_jid}" if phone_e164.blank?

      # Contact
      contact = account.contacts.where(phone_number: phone_e164).first_or_initialize
      if contact.new_record?
        contact.name         = push_name.presence || phone_e164
        contact.identifier   = contact.identifier.presence || phone_e164 if contact.respond_to?(:identifier)
        contact.phone_number = phone_e164
        contact.save!
      elsif contact.name.blank? && push_name.present?
        contact.update!(name: push_name)
      end

      # Somente salvar URL da foto (sem anexar avatar)
      if profile_pic.present?
        if contact.respond_to?(:custom_attributes)
          ca = (contact.custom_attributes || {}).dup
          if ca['wa_profile_pic_url'] != profile_pic
            ca['wa_profile_pic_url'] = profile_pic
            contact.update!(custom_attributes: ca)
          end
        elsif contact.respond_to?(:additional_attributes)
          aa = (contact.additional_attributes || {}).dup
          if aa['wa_profile_pic_url'] != profile_pic
            aa['wa_profile_pic_url'] = profile_pic
            contact.update!(additional_attributes: aa)
          end
        end
      end

      # ContactInbox (sem ContactBuilder)
      ci = ContactInbox.find_by(inbox_id: inbox.id, source_id: phone_e164)
      unless ci
        ci = ContactInbox.create!(
          contact:   contact,
          inbox:     inbox,
          source_id: phone_e164
        )
      end

      [ci, contact]
    end

    # Conversa aberta ou cria nova
    def find_or_open_conversation!(account:, inbox:, contact_inbox:)
      convo = ::Conversation
                .where(inbox_id: inbox.id, contact_id: contact_inbox.contact_id)
                .where.not(status: :resolved)
                .order(id: :desc)
                .first

      convo || ::Conversation.create!(
        account_id:            account.id,
        inbox_id:              inbox.id,
        contact_id:            contact_inbox.contact_id,
        contact_inbox_id:      contact_inbox.id,
        status:                :open,
        additional_attributes: {},
        custom_attributes:     {}
      )
    end

    # Compat antigo
    def find_or_create_conversation(contact_inbox)
      inbox   = contact_inbox.inbox
      account = inbox.account
      find_or_open_conversation!(account: account, inbox: inbox, contact_inbox: contact_inbox)
    end
  end
end
