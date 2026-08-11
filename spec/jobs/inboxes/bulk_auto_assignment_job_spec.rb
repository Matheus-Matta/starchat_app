require 'rails_helper'

# ─────────────────────────────────────────────────────────────────────────────
# Suite: Inboxes::BulkAutoAssignmentJob
#
# Cenários cobertos:
#   v2 habilitado:
#     1. Usa AssignmentService.perform_bulk_assignment (policy-aware)
#     2. Loga o número de atribuições
#     3. Skips inboxes com auto_assignment desabilitado
#     4. Processes cloud accounts without plan gating
#
#   v2 desabilitado (legado):
#     5. Usa AgentAssignmentService por conversa
#     6. Loga aviso quando não há agentes disponíveis
#     7. Não processa quando não há agentes
#
#   Outros:
#     8. Não processa quando feature assignment_v2 está desabilitada
# ─────────────────────────────────────────────────────────────────────────────
RSpec.describe Inboxes::BulkAutoAssignmentJob do
  let(:account) { create(:account) }
  let(:agent)   { create(:user, account: account, role: :agent, auto_offline: false) }
  let(:inbox)   { create(:inbox, account: account, enable_auto_assignment: true) }
  let!(:conversation) { create(:conversation, account: account, inbox: inbox, assignee: nil, status: :open) }

  before { account.enable_features!('assignment_v2') }

  # ════════════════════════════════════════════════════════════════════════════
  # Cenário 1-4: assignment_v2 habilitado (caminho novo / policy-aware)
  # ════════════════════════════════════════════════════════════════════════════
  context 'quando assignment_v2 está habilitado' do
    before { create(:inbox_member, user: agent, inbox: inbox) }

    it 'usa AssignmentService.perform_bulk_assignment em vez de AgentAssignmentService' do
      assignment_service = instance_double(AutoAssignment::AssignmentService, perform_bulk_assignment: 1)
      allow(AutoAssignment::AssignmentService).to receive(:new).with(inbox: inbox).and_return(assignment_service)

      expect(assignment_service).to receive(:perform_bulk_assignment)
      expect(AutoAssignment::AgentAssignmentService).not_to receive(:new)

      described_class.perform_now
    end

    it 'passa o limite correto ao perform_bulk_assignment' do
      assignment_service = instance_double(AutoAssignment::AssignmentService)
      allow(AutoAssignment::AssignmentService).to receive(:new).and_return(assignment_service)
      expect(assignment_service).to receive(:perform_bulk_assignment)
        .with(limit: Limits::AUTO_ASSIGNMENT_BULK_LIMIT)
        .and_return(0)

      described_class.perform_now
    end

    it 'loga o número de conversas atribuídas' do
      assignment_service = instance_double(AutoAssignment::AssignmentService, perform_bulk_assignment: 3)
      allow(AutoAssignment::AssignmentService).to receive(:new).with(inbox: inbox).and_return(assignment_service)
      allow(Rails.logger).to receive(:info)

      expect(Rails.logger).to receive(:info)
        .with("[BulkAutoAssignment] inbox=#{inbox.id} assigned=3 (v2 policy)")

      described_class.perform_now
    end

    it 'skips inboxes com auto assignment desabilitado' do
      inbox.update!(enable_auto_assignment: false)
      expect(AutoAssignment::AssignmentService).not_to receive(:new)

      described_class.perform_now
    end

    context 'quando conta está no chatwoot cloud' do
      before do
        account.update!(custom_attributes: {})
        allow(StarchatsApp).to receive(:chatwoot_cloud?).and_return(true)
      end

      it 'processa auto assignment normalmente' do
        assignment_service = instance_double(AutoAssignment::AssignmentService, perform_bulk_assignment: 1)
        expect(AutoAssignment::AssignmentService).to receive(:new).with(inbox: inbox).and_return(assignment_service)

        described_class.perform_now
      end
    end

    context 'com múltiplas inboxes' do
      let(:inbox2) { create(:inbox, account: account, enable_auto_assignment: true) }

      before { create(:inbox_member, user: agent, inbox: inbox2) }

      it 'processa cada inbox independentemente' do
        svc1 = instance_double(AutoAssignment::AssignmentService, perform_bulk_assignment: 1)
        svc2 = instance_double(AutoAssignment::AssignmentService, perform_bulk_assignment: 2)
        allow(AutoAssignment::AssignmentService).to receive(:new).with(inbox: inbox).and_return(svc1)
        allow(AutoAssignment::AssignmentService).to receive(:new).with(inbox: inbox2).and_return(svc2)

        expect(svc1).to receive(:perform_bulk_assignment)
        expect(svc2).to receive(:perform_bulk_assignment)

        described_class.perform_now
      end
    end
  end

  # ════════════════════════════════════════════════════════════════════════════
  # Cenários 5-7: legacy (assignment_v2 ativado mas sem os controles novos)
  # Simulamos o caminho legado usando allow_any_instance_of para simular
  # inbox.auto_assignment_v2_enabled? = false
  # ════════════════════════════════════════════════════════════════════════════
  context 'caminho legado (auto_assignment_v2_enabled? = false)' do
    before do
      create(:inbox_member, user: agent, inbox: inbox)
      allow_any_instance_of(Inbox).to receive(:auto_assignment_v2_enabled?).and_return(false)
    end

    it 'usa AgentAssignmentService por conversa' do
      assignment_service = instance_double(AutoAssignment::AgentAssignmentService)
      allow(assignment_service).to receive(:perform)
      allow(AutoAssignment::AgentAssignmentService).to receive(:new).with(
        conversation: conversation,
        allowed_agent_ids: [agent.id]
      ).and_return(assignment_service)

      expect(assignment_service).to receive(:perform)
      expect(AutoAssignment::AssignmentService).not_to receive(:new)

      described_class.perform_now
    end

    it 'não usa AgentAssignmentService quando não há agentes' do
      InboxMember.where(inbox: inbox).destroy_all
      allow(Rails.logger).to receive(:info)
      expect(Rails.logger).to receive(:info)
        .with("No agents available to assign conversation to inbox #{inbox.id}")
      expect(AutoAssignment::AgentAssignmentService).not_to receive(:new)

      described_class.perform_now
    end
  end

  # ════════════════════════════════════════════════════════════════════════════
  # Cenário 8: feature assignment_v2 desabilitada — job não processa nenhuma inbox
  # ════════════════════════════════════════════════════════════════════════════
  context 'quando assignment_v2 está desabilitado na conta' do
    before { account.disable_features!('assignment_v2') }

    it 'não processa nenhuma inbox' do
      expect(AutoAssignment::AssignmentService).not_to receive(:new)
      expect(AutoAssignment::AgentAssignmentService).not_to receive(:new)

      described_class.perform_now
    end
  end
end
