# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Evolution::ContactSyncService, type: :service do
  let(:account) { create(:account) }

  # Helper para criar inbox com provider_config de settings
  def build_inbox(sync_contact_name: nil)
    config = sync_contact_name.nil? ? {} : { 'settings' => { 'syncContactName' => sync_contact_name } }
    channel = create(:channel_evolution, account: account, provider_config: config)
    channel.inbox
  end

  def list_entry(remote_jid:, push_name: nil, pic_url: nil)
    entry = { 'remoteJid' => remote_jid }
    entry['pushName']       = push_name if push_name
    entry['profilePicUrl']  = pic_url   if pic_url
    entry
  end

  # ─── syncContactName ausente (default = false) ────────────────────────────

  describe 'quando syncContactName não está configurado (default false)' do
    let(:inbox) { build_inbox }

    context 'contato novo (sem nome)' do
      it 'define o pushName mesmo com a feature desabilitada (inicialização única)' do
        described_class.new(
          inbox: inbox,
          list: [list_entry(remote_jid: '5521999990001@s.whatsapp.net', push_name: 'João Silva')]
        ).perform

        contact = Contact.find_by(phone_number: '+5521999990001')
        expect(contact).to be_present
        expect(contact.name).to eq('João Silva')
      end
    end

    context 'contato existente com nome numérico (placeholder)' do
      it 'substitui o placeholder pelo pushName (inicialização única)' do
        contact = create(:contact, account: account, name: '5521999990002', phone_number: '+5521999990002')
        create(:contact_inbox, contact: contact, inbox: inbox, source_id: '5521999990002')

        described_class.new(
          inbox: inbox,
          list: [list_entry(remote_jid: '5521999990002@s.whatsapp.net', push_name: 'Maria Souza')]
        ).perform

        expect(contact.reload.name).to eq('Maria Souza')
      end
    end

    context 'contato existente com nome real' do
      it 'NÃO sobrescreve o nome real quando syncContactName = false' do
        contact = create(:contact, account: account, name: 'Nome Existente', phone_number: '+5521999990003')
        create(:contact_inbox, contact: contact, inbox: inbox, source_id: '5521999990003')

        described_class.new(
          inbox: inbox,
          list: [list_entry(remote_jid: '5521999990003@s.whatsapp.net', push_name: 'Novo Nome WA')]
        ).perform

        expect(contact.reload.name).to eq('Nome Existente')
      end
    end
  end

  # ─── syncContactName = true ───────────────────────────────────────────────

  describe 'quando syncContactName = true' do
    let(:inbox) { build_inbox(sync_contact_name: true) }

    context 'contato novo' do
      it 'define o pushName' do
        described_class.new(
          inbox: inbox,
          list: [list_entry(remote_jid: '5521888880001@s.whatsapp.net', push_name: 'Carlos Teste')]
        ).perform

        contact = Contact.find_by(phone_number: '+5521888880001')
        expect(contact&.name).to eq('Carlos Teste')
      end
    end

    context 'contato existente com nome real diferente' do
      it 'atualiza o nome para o pushName' do
        contact = create(:contact, account: account, name: 'Nome Antigo', phone_number: '+5521888880002')
        create(:contact_inbox, contact: contact, inbox: inbox, source_id: '5521888880002')

        described_class.new(
          inbox: inbox,
          list: [list_entry(remote_jid: '5521888880002@s.whatsapp.net', push_name: 'Nome Novo WA')]
        ).perform

        expect(contact.reload.name).to eq('Nome Novo WA')
      end
    end

    context 'contato existente com nome real igual ao pushName' do
      it 'não altera o contato' do
        contact = create(:contact, account: account, name: 'Mesmo Nome', phone_number: '+5521888880003')
        create(:contact_inbox, contact: contact, inbox: inbox, source_id: '5521888880003')

        expect(contact).not_to receive(:update!)

        described_class.new(
          inbox: inbox,
          list: [list_entry(remote_jid: '5521888880003@s.whatsapp.net', push_name: 'Mesmo Nome')]
        ).perform
      end
    end
  end

  # ─── syncContactName = false (explícito) ──────────────────────────────────

  describe 'quando syncContactName = false (explícito)' do
    let(:inbox) { build_inbox(sync_contact_name: false) }

    it 'NÃO atualiza contato com nome real' do
      contact = create(:contact, account: account, name: 'Nome Preservado', phone_number: '+5521777770001')
      create(:contact_inbox, contact: contact, inbox: inbox, source_id: '5521777770001')

      described_class.new(
        inbox: inbox,
        list: [list_entry(remote_jid: '5521777770001@s.whatsapp.net', push_name: 'Nome Novo WA')]
      ).perform

      expect(contact.reload.name).to eq('Nome Preservado')
    end

    it 'AINDA inicializa contato novo com pushName' do
      described_class.new(
        inbox: inbox,
        list: [list_entry(remote_jid: '5521777770002@s.whatsapp.net', push_name: 'Pedro Init')]
      ).perform

      contact = Contact.find_by(phone_number: '+5521777770002')
      expect(contact&.name).to eq('Pedro Init')
    end
  end

  # ─── Sem pushName ─────────────────────────────────────────────────────────

  describe 'quando pushName está ausente' do
    let(:inbox) { build_inbox(sync_contact_name: true) }

    it 'usa o número como nome do contato' do
      described_class.new(
        inbox: inbox,
        list: [list_entry(remote_jid: '5521666660001@s.whatsapp.net')]
      ).perform

      contact = Contact.find_by(phone_number: '+5521666660001')
      expect(contact).to be_present
      expect(contact.name).to eq('+5521666660001')
    end
  end

  # ─── pushName numérico ────────────────────────────────────────────────────

  describe 'quando pushName é numérico' do
    let(:inbox) { build_inbox(sync_contact_name: true) }

    it 'usa o número e164 como nome (pushName numérico é ignorado)' do
      described_class.new(
        inbox: inbox,
        list: [list_entry(remote_jid: '5521666660002@s.whatsapp.net', push_name: '5521666660002')]
      ).perform

      contact = Contact.find_by(phone_number: '+5521666660002')
      expect(contact.name).to eq('+5521666660002')
    end
  end
end
