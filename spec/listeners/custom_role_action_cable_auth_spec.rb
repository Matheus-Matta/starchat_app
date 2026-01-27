require 'rails_helper'

describe ActionCableListener do
  let(:listener) { described_class.instance }
  let!(:account) { create(:account) }
  let!(:admin) { create(:user, account: account, role: :administrator) }
  let!(:inbox) { create(:inbox, account: account) }

  # --- CONFIGURAÇÃO DE AGENTES E ROLES ---

  # 1. Agente Padrão (Sem Custom Role) - Deve ver tudo
  let!(:standard_agent) { create(:user, account: account, role: :agent) }

  # 2. Gerenciar todas as conversas (conversation_manage)
  let!(:full_access_role) { create(:custom_role, account: account, permissions: ['conversation_manage']) }
  let!(:full_access_agent) { create(:user, account: account, role: :agent) }

  # 3. Gerenciar conversas do time (conversation_team_manage)
  #    & as que lhe estão atribuídas (implícito)
  let!(:team_role) { create(:custom_role, account: account, permissions: ['conversation_team_manage']) }
  let!(:team_agent) { create(:user, account: account, role: :agent) }
  let!(:team) { create(:team, account: account) }

  # 4. Gerenciar conversas não atribuídas (conversation_unassigned_manage)
  #    & as que lhe estão atribuídas (implícito)
  let!(:unassigned_role) { create(:custom_role, account: account, permissions: ['conversation_unassigned_manage']) }
  let!(:unassigned_agent) { create(:user, account: account, role: :agent) }

  # 5. Gerenciar conversas em que participa (conversation_participating_manage)
  #    (leia-se: assigned to self + participating)
  let!(:participating_role) { create(:custom_role, account: account, permissions: ['conversation_participating_manage']) }
  let!(:participating_agent) { create(:user, account: account, role: :agent) }

  before do
    # Adicionar todos como membros do inbox para serem elegíveis
    [standard_agent, full_access_agent, team_agent, unassigned_agent, participating_agent].each do |agent|
      create(:inbox_member, inbox: inbox, user: agent)
    end

    # Associar Custom Roles
    full_access_agent.account_users.find_by(account: account).update(custom_role: full_access_role)
    team_agent.account_users.find_by(account: account).update(custom_role: team_role)
    unassigned_agent.account_users.find_by(account: account).update(custom_role: unassigned_role)
    participating_agent.account_users.find_by(account: account).update(custom_role: participating_role)

    # Configurar Time
    create(:team_member, team: team, user: team_agent)

    Current.user = nil
    Current.account = nil
  end

  describe '#message_created broadcasting rules' do
    let(:event_name) { :'message.created' }

    # Helper para montar a lista base de quem SEMPRE recebe
    def base_recipients(conversation)
      [
        admin.pubsub_token,          # Admin sempre recebe
        standard_agent.pubsub_token, # Agente padrão sempre recebe
        full_access_agent.pubsub_token, # Agente Full Access sempre recebe
        conversation.contact_inbox.pubsub_token # Contato sempre recebe (exceto private/activity, mas aqui é msg normal)
      ]
    end

    context 'CASE 1: Conversation Unassigned' do
      let!(:conversation) { create(:conversation, account: account, inbox: inbox, assignee: nil) }
      let!(:message) { create(:message, account: account, inbox: inbox, conversation: conversation) }
      let!(:event) { Events::Base.new(event_name, Time.zone.now, message: message) }

      it 'notifies expected agents' do
        recipients = base_recipients(conversation)

        # Quem MAIS deve receber:
        # - Unassigned Agent: SIM (permissão conversation_unassigned_manage)
        recipients << unassigned_agent.pubsub_token

        # Quem NÃO deve receber:
        # - Participating Agent: NÃO (não é assignee, não está participando)
        # - Team Agent: NÃO (conversa sem time)

        expect(ActionCableBroadcastJob).to receive(:perform_later).with(
          a_collection_containing_exactly(*recipients),
          'message.created',
          anything
        )

        listener.message_created(event)
      end
    end

    context 'CASE 2: Conversation Assigned to Participating Agent' do
      let!(:conversation) { create(:conversation, account: account, inbox: inbox, assignee: participating_agent) }
      let!(:message) { create(:message, account: account, inbox: inbox, conversation: conversation) }
      let!(:event) { Events::Base.new(event_name, Time.zone.now, message: message) }

      it 'notifies assignee and allowed roles' do
        recipients = base_recipients(conversation)

        # Quem MAIS deve receber:
        # - Participating Agent: SIM (é o assignee)
        recipients << participating_agent.pubsub_token

        # Quem NÃO deve receber:
        # - Unassigned Agent: NÃO (está atribuída)
        # - Team Agent: NÃO (sem time)

        expect(ActionCableBroadcastJob).to receive(:perform_later).with(
          a_collection_containing_exactly(*recipients),
          'message.created',
          anything
        )

        listener.message_created(event)
      end
    end

    context 'CASE 3: Conversation Assigned to Team Agent' do
      let!(:conversation) { create(:conversation, account: account, inbox: inbox, assignee: team_agent) }
      let!(:message) { create(:message, account: account, inbox: inbox, conversation: conversation) }
      let!(:event) { Events::Base.new(event_name, Time.zone.now, message: message) }

      it 'notifies assignee' do
        recipients = base_recipients(conversation)

        # Quem MAIS deve receber:
        # - Team Agent: SIM (é o assignee - independente de permissão de time)
        recipients << team_agent.pubsub_token

        expect(ActionCableBroadcastJob).to receive(:perform_later).with(
          a_collection_containing_exactly(*recipients),
          'message.created',
          anything
        )

        listener.message_created(event)
      end
    end

    context 'CASE 4: Conversation Assigned to Someone Else (Standard Agent)' do
      let!(:conversation) { create(:conversation, account: account, inbox: inbox, assignee: standard_agent) }
      let!(:message) { create(:message, account: account, inbox: inbox, conversation: conversation) }
      let!(:event) { Events::Base.new(event_name, Time.zone.now, message: message) }

      it 'restricts access to unauthorized custom roles' do
        recipients = base_recipients(conversation)

        # Quem MAIS deve receber:
        # Ninguém extra.

        # Participating Agent: NÃO está participando.
        # Team Agent: NÃO é do time.
        # Unassigned Agent: NÃO é unassigned.

        # Verificação explícita de exclusão
        unexpected_tokens = [
          participating_agent.pubsub_token,
          team_agent.pubsub_token,
          unassigned_agent.pubsub_token
        ]

        # Validando que standard_agent recebe (já está no base_recipients)

        expect(ActionCableBroadcastJob).to receive(:perform_later) do |tokens, _, _|
          expect(tokens).to include(*recipients)
          expect(tokens).not_to include(*unexpected_tokens)
        end

        listener.message_created(event)
      end
    end

    context 'CASE 5: Conversation Assigned to Team (No individual assignee)' do
      let!(:conversation) { create(:conversation, account: account, inbox: inbox, assignee: nil, team: team) }
      let!(:message) { create(:message, account: account, inbox: inbox, conversation: conversation) }
      let!(:event) { Events::Base.new(event_name, Time.zone.now, message: message) }

      it 'notifies team members and unassigned managers' do
        recipients = base_recipients(conversation)

        # Quem MAIS deve receber:
        # - Team Agent: SIM (conversa é do time dele + ele tem permissão conversation_team_manage)
        recipients << team_agent.pubsub_token

        # - Unassigned Agent: SIM (conversa não tem assignee individual, logo perm 'conversation_unassigned_manage' aplica)
        recipients << unassigned_agent.pubsub_token

        expect(ActionCableBroadcastJob).to receive(:perform_later).with(
          a_collection_containing_exactly(*recipients),
          'message.created',
          anything
        )

        listener.message_created(event)
      end
    end

    context 'CASE 6: Conversation Assigned to Team AND Individual (in team)' do
      # Atribuída a 'other_in_team' (agente fictício no mesmo time), para testar se o 'team_agent' vê.
      let!(:other_in_team) { create(:user, account: account, role: :agent) }
      let(:conversation) { create(:conversation, account: account, inbox: inbox, assignee: other_in_team, team: team) }
      let(:message) { create(:message, account: account, inbox: inbox, conversation: conversation) }
      let(:event) { Events::Base.new(event_name, Time.zone.now, message: message) }

      before do
        create(:inbox_member, inbox: inbox, user: other_in_team)
        create(:team_member, team: team, user: other_in_team)
      end

      it 'notifies team members even if assigned to another' do
        # Forçar criação antes do expect para evitar captura de side-effects (como contact.created)
        evt = event

        recipients = base_recipients(conversation)
        recipients << other_in_team.pubsub_token # Assignee vê
        recipients << team_agent.pubsub_token # Team Agent vê (e é do mesmo time)

        expect(ActionCableBroadcastJob).to receive(:perform_later).with(
          a_collection_containing_exactly(*recipients),
          'message.created',
          anything
        )

        listener.message_created(evt)
      end
    end
  end

  describe 'End-to-End Simulation: Conversation Created + First Message' do
    # Helper para validar broadcast para lista de tokens
    def expect_broadcast(tokens, event_type)
      expect(ActionCableBroadcastJob).to receive(:perform_later).with(
        a_collection_containing_exactly(*tokens),
        event_type,
        anything
      )
    end

    # Helper base recipients (Admin + Standard + Full Access + Contact)
    def universal_recipients(conversation)
      [
        admin.pubsub_token,
        standard_agent.pubsub_token,
        full_access_agent.pubsub_token,
        conversation.contact_inbox.pubsub_token
      ]
    end

    context 'Scenario A: New Inquiry (Unisigned, No Team)' do
      let(:conversation) { create(:conversation, account: account, inbox: inbox, assignee: nil, team: nil) }
      let(:message) { create(:message, account: account, inbox: inbox, conversation: conversation) }
      let(:created_event) { Events::Base.new(:'conversation.created', Time.zone.now, conversation: conversation) }
      let(:message_event) { Events::Base.new(:'message.created', Time.zone.now, message: message) }

      it 'broadcasts creation and message to Unassigned Managers' do
        # Setup: Garantir criação dos objetos antes de ouvir broadcasts
        conversation
        message

        # Expectation: Unassigned Agent should see it. Team Agent should NOT. Participating Agent should NOT.
        expected = universal_recipients(conversation) + [unassigned_agent.pubsub_token]

        # 1. Conversation Created
        expect_broadcast(expected, 'conversation.created')
        listener.conversation_created(created_event)

        # 2. Message Created
        expect_broadcast(expected, 'message.created')
        listener.message_created(message_event)
      end
    end

    context 'Scenario B: Team Handoff (Unisigned, Assigned to Team)' do
      let(:conversation) { create(:conversation, account: account, inbox: inbox, assignee: nil, team: team) }
      let(:message) { create(:message, account: account, inbox: inbox, conversation: conversation) }
      let(:created_event) { Events::Base.new(:'conversation.created', Time.zone.now, conversation: conversation) }
      let(:message_event) { Events::Base.new(:'message.created', Time.zone.now, message: message) }

      it 'broadcasts to Team Members and Unassigned Managers' do
        # Expectation:
        # - Team Agent: YES (Team matches)
        # - Unassigned Agent: YES (Is unassigned)
        expected = universal_recipients(conversation) + [team_agent.pubsub_token, unassigned_agent.pubsub_token]

        # 1. Conversation Created
        expect_broadcast(expected, 'conversation.created')
        listener.conversation_created(created_event)

        # 2. Message Created
        expect_broadcast(expected, 'message.created')
        listener.message_created(message_event)
      end
    end

    context 'Scenario C: Direct Assignment (Assigned to Participating Agent, No Team)' do
      let(:conversation) { create(:conversation, account: account, inbox: inbox, assignee: participating_agent, team: nil) }
      let(:message) { create(:message, account: account, inbox: inbox, conversation: conversation) }
      let(:created_event) { Events::Base.new(:'conversation.created', Time.zone.now, conversation: conversation) }
      let(:message_event) { Events::Base.new(:'message.created', Time.zone.now, message: message) }

      it 'broadcasts only to Assignee (Participant)' do
        # Expectation:
        # - Participating Agent: YES (Is Assignee)
        # - Unassigned Agent: NO (Is Assigned)
        # - Team Agent: NO (No Team)
        expected = universal_recipients(conversation) + [participating_agent.pubsub_token]

        # 1. Conversation Created
        expect_broadcast(expected, 'conversation.created')
        listener.conversation_created(created_event)

        # 2. Message Created
        expect_broadcast(expected, 'message.created')
        listener.message_created(message_event)
      end
    end

    context 'Scenario D: Team Assignment (Assigned to Other Team Member, With Team)' do
      let(:other_member) { create(:user, account: account, role: :agent) }
      let(:conversation) { create(:conversation, account: account, inbox: inbox, assignee: other_member, team: team) }
      let(:message) { create(:message, account: account, inbox: inbox, conversation: conversation) }
      let(:created_event) { Events::Base.new(:'conversation.created', Time.zone.now, conversation: conversation) }
      let(:message_event) { Events::Base.new(:'message.created', Time.zone.now, message: message) }

      before do
        create(:inbox_member, inbox: inbox, user: other_member)
        create(:team_member, team: team, user: other_member)
      end

      it 'broadcasts to Assignee and Team Watchers' do
        # Expectation:
        # - Other Member: YES (Assignee)
        # - Team Agent: YES (Team Match + Perm)
        # - Unassigned Agent: NO (Is Assigned)
        expected = universal_recipients(conversation) + [other_member.pubsub_token, team_agent.pubsub_token]

        # 1. Conversation Created
        expect_broadcast(expected, 'conversation.created')
        listener.conversation_created(created_event)

        # 2. Message Created
        expect_broadcast(expected, 'message.created')
        listener.message_created(message_event)
      end
    end
  end
end
