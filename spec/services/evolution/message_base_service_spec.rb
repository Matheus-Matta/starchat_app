# frozen_string_literal: true

require 'rails_helper'

# MessageBaseService é abstrata – criamos subclasse concreta só para testes
class TestableMessageBaseService < Evolution::MessageBaseService
  # Usa processed_params (já convertido para HashWithIndifferentAccess no init)
  # para garantir que o .dig com chaves symbol funcione corretamente
  def call_ensure_contact!
    ensure_contact_from_message!(processed_params)
  end

  # Stubs mínimos para não depender de download/attach
  def attach_from_payload!(_msg, _payload) = false
end

RSpec.describe Evolution::MessageBaseService, type: :service do
  let(:account) { create(:account) }

  def build_inbox(sync_contact_name: nil)
    config = sync_contact_name.nil? ? {} : { 'settings' => { 'syncContactName' => sync_contact_name } }
    channel = create(:channel_evolution, account: account, provider_config: config)
    channel.inbox
  end

  def incoming_message(remote_jid:, push_name: nil, from_me: false, msg_id: 'MSG1')
    {
      'key' => {
        'remoteJid' => remote_jid,
        'fromMe'    => from_me,
        'id'        => msg_id
      },
      'pushName' => push_name,
      'message'  => { 'conversation' => 'Olá' }
    }.compact
  end

  def run_service(inbox, message)
    TestableMessageBaseService.new(inbox: inbox, processed: message).call_ensure_contact!
  end

  # ─── syncContactName ausente (default = false) ─────────────────────────

  describe 'contact name — default (syncContactName não configurado = false)' do
    let(:inbox) { build_inbox }

    it 'contato novo: define pushName (inicialização única)' do
      run_service(inbox, incoming_message(remote_jid: '5521111110001@s.whatsapp.net', push_name: 'Ana Lima'))

      contact = Contact.find_by(phone_number: '+5521111110001')
      expect(contact).to be_present
      expect(contact.name).to eq('Ana Lima')
    end

    it 'contato com placeholder numérico: substitui pelo pushName' do
      contact = create(:contact, account: account, name: '5521111110002', phone_number: '+5521111110002')
      create(:contact_inbox, contact: contact, inbox: inbox, source_id: '5521111110002')

      run_service(inbox, incoming_message(remote_jid: '5521111110002@s.whatsapp.net', push_name: 'Bruno Castro'))

      expect(contact.reload.name).to eq('Bruno Castro')
    end

    it 'contato com nome real: NÃO sobrescreve (syncContactName = false)' do
      contact = create(:contact, account: account, name: 'Nome Real', phone_number: '+5521111110003')
      create(:contact_inbox, contact: contact, inbox: inbox, source_id: '5521111110003')

      run_service(inbox, incoming_message(remote_jid: '5521111110003@s.whatsapp.net', push_name: 'Novo Nome'))

      expect(contact.reload.name).to eq('Nome Real')
    end
  end

  # ─── syncContactName = true ────────────────────────────────────────────

  describe 'contact name — syncContactName = true' do
    let(:inbox) { build_inbox(sync_contact_name: true) }

    it 'contato novo: define pushName' do
      run_service(inbox, incoming_message(remote_jid: '5521222220001@s.whatsapp.net', push_name: 'Clara Dias'))

      contact = Contact.find_by(phone_number: '+5521222220001')
      expect(contact&.name).to eq('Clara Dias')
    end

    it 'contato com nome real diferente: atualiza para o pushName' do
      contact = create(:contact, account: account, name: 'Nome Antigo', phone_number: '+5521222220002')
      create(:contact_inbox, contact: contact, inbox: inbox, source_id: '5521222220002')

      run_service(inbox, incoming_message(remote_jid: '5521222220002@s.whatsapp.net', push_name: 'Novo WA'))

      expect(contact.reload.name).to eq('Novo WA')
    end

    it 'contato com nome real igual ao pushName: não faz update desnecessário' do
      contact = create(:contact, account: account, name: 'Mesmo Nome', phone_number: '+5521222220003')
      create(:contact_inbox, contact: contact, inbox: inbox, source_id: '5521222220003')

      run_service(inbox, incoming_message(remote_jid: '5521222220003@s.whatsapp.net', push_name: 'Mesmo Nome'))

      expect(contact.reload.name).to eq('Mesmo Nome')
    end
  end

  # ─── syncContactName = false (explícito) ───────────────────────────────

  describe 'contact name — syncContactName = false (explícito)' do
    let(:inbox) { build_inbox(sync_contact_name: false) }

    it 'NÃO atualiza nome real existente' do
      contact = create(:contact, account: account, name: 'Preservado', phone_number: '+5521333330001')
      create(:contact_inbox, contact: contact, inbox: inbox, source_id: '5521333330001')

      run_service(inbox, incoming_message(remote_jid: '5521333330001@s.whatsapp.net', push_name: 'Sobrescrever?'))

      expect(contact.reload.name).to eq('Preservado')
    end

    it 'AINDA inicializa contato novo com pushName' do
      run_service(inbox, incoming_message(remote_jid: '5521333330002@s.whatsapp.net', push_name: 'Init Once'))

      contact = Contact.find_by(phone_number: '+5521333330002')
      expect(contact&.name).to eq('Init Once')
    end
  end

  # ─── lock_name ─────────────────────────────────────────────────────────

  describe 'contact name — lock_name = true' do
    let(:inbox) { build_inbox(sync_contact_name: true) }

    it 'nunca atualiza contato com lock_name mesmo com syncContactName ativo' do
      contact = create(:contact, account: account, name: 'Bloqueado', phone_number: '+5521444440001',
                                 custom_attributes: { 'lock_name' => true })
      create(:contact_inbox, contact: contact, inbox: inbox, source_id: '5521444440001')

      run_service(inbox, incoming_message(remote_jid: '5521444440001@s.whatsapp.net', push_name: 'Tentar mudar'))

      expect(contact.reload.name).to eq('Bloqueado')
    end
  end

  # ─── Sem pushName ──────────────────────────────────────────────────────

  describe 'contact name — sem pushName' do
    let(:inbox) { build_inbox(sync_contact_name: true) }

    it 'usa o número e164 como nome para contato novo' do
      run_service(inbox, incoming_message(remote_jid: '5521555550001@s.whatsapp.net'))

      contact = Contact.find_by(phone_number: '+5521555550001')
      expect(contact).to be_present
      expect(contact.name).to eq('+5521555550001')
    end
  end

  # ─── Mensagem outgoing (fromMe) ────────────────────────────────────────

  describe 'contact name — mensagem fromMe' do
    let(:inbox) { build_inbox(sync_contact_name: true) }

    it 'não aplica lógica de pushName para mensagem própria' do
      contact = create(:contact, account: account, name: 'Nome Existente', phone_number: '+5521666660001')
      create(:contact_inbox, contact: contact, inbox: inbox, source_id: '5521666660001')

      run_service(inbox, incoming_message(
                           remote_jid: '5521666660001@s.whatsapp.net',
                           push_name: 'Eu Mesmo',
                           from_me: true
                         ))

      expect(contact.reload.name).to eq('Nome Existente')
    end
  end
end
