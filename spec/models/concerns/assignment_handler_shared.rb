# frozen_string_literal: true

require 'rails_helper'

shared_examples_for 'assignment_handler' do
  describe '#update_team' do
    let(:conversation) { create(:conversation, assignee: create(:user)) }
    let(:agent) do
      create(:user, email: 'agent@example.com', account: conversation.account, role: :agent, auto_offline: false)
    end
    let(:team) do
      create(:team, account: conversation.account, allow_auto_assign: false)
    end

    context 'when agent is current user' do
      before do
        Current.user = agent
        create(:team_member, team: team, user: agent)
        create(:inbox_member, user: agent, inbox: conversation.inbox)
        conversation.inbox.reload
      end

      it 'creates team assigned and unassigned message activity' do
        expect(conversation.update(team: team)).to be true
        expect(conversation.update(team: nil)).to be true
        expect(Conversations::ActivityMessageJob).to(have_been_enqueued.at_least(:once)
          .with(conversation, { account_id: conversation.account_id, inbox_id: conversation.inbox_id, message_type: :activity,
                                content: "Assigned to #{team.name} by #{agent.name}"  }))
        expect(Conversations::ActivityMessageJob).to(have_been_enqueued.at_least(:once)
          .with(conversation, { account_id: conversation.account_id, inbox_id: conversation.inbox_id, message_type: :activity,
                                content: "Unassigned from #{team.name} by #{agent.name}" }))
      end

      it 'changes assignee to nil if they doesnt belong to the team and allow_auto_assign is false' do
        expect(team.allow_auto_assign).to be false

        conversation.update(team: team)

        expect(conversation.reload.assignee).to be_nil
      end

      it 'changes assignee to a team member if allow_auto_assign is enabled' do
        team.update!(allow_auto_assign: true)

        conversation.update(team: team)

        expect(conversation.reload.assignee).to eq agent
        expect(Conversations::ActivityMessageJob).to(have_been_enqueued.at_least(:once)
          .with(conversation, { account_id: conversation.account_id, inbox_id: conversation.inbox_id, message_type: :activity,
                                content: "Assigned to #{conversation.assignee.name} via #{team.name} by #{agent.name}" }))
      end

      it 'wont change assignee if he is already a team member' do
        team.update!(allow_auto_assign: true)
        assignee = create(:user, account: conversation.account, role: :agent)
        create(:inbox_member, user: assignee, inbox: conversation.inbox)
        create(:team_member, team: team, user: assignee)
        conversation.update(assignee: assignee)

        conversation.update(team: team)

        expect(conversation.reload.assignee).to eq assignee
      end
    end
  end

  # ════════════════════════════════════════════════════════════════════════════
  # assignment_v2: encaminhamento para time usa PolicyAgentSelector
  # ════════════════════════════════════════════════════════════════════════════
  describe '#find_assignee_from_team com assignment_v2' do
    let(:account) { create(:account) }
    let(:inbox)   { create(:inbox, account: account, enable_auto_assignment: true) }
    let(:conversation) { create(:conversation, account: account, inbox: inbox) }

    let(:agent) { create(:user, account: account, role: :agent, auto_offline: false) }
    let(:team)  { create(:team, account: conversation.account, allow_auto_assign: true) }

    before do
      account.enable_features!('assignment_v2')
      create(:inbox_member, user: agent, inbox: inbox)
      create(:team_member, team: team, user: agent)
      inbox.reload

      OnlineStatusTracker.update_presence(account.id, 'User', agent.id)
      OnlineStatusTracker.set_status(account.id, agent.id, 'online')
    end

    context 'quando assignment_v2 está habilitado' do
      it 'usa PolicyAgentSelector em vez de AgentAssignmentService' do
        selector = instance_double(AutoAssignment::PolicyAgentSelector, find_assignee: agent)
        expect(AutoAssignment::PolicyAgentSelector).to receive(:new).with(
          inbox: inbox,
          allowed_agent_ids: array_including(agent.id)
        ).and_return(selector)
        expect(AutoAssignment::AgentAssignmentService).not_to receive(:new)

        conversation.update!(team: team)
      end

      it 'atribui agente do time ao encaminhar via allow_auto_assign' do
        conversation.update!(team: team)
        expect(conversation.reload.assignee).to eq(agent)
      end

      it 'não atribui agente quando allow_auto_assign=false no time' do
        team.update!(allow_auto_assign: false)
        conversation.update!(team: team)
        expect(conversation.reload.assignee).to be_nil
      end

      context 'com política balanced' do
        before do
          policy = create(:assignment_policy, account: account, assignment_order: :balanced, enabled: true)
          create(:inbox_assignment_policy, inbox: inbox, assignment_policy: policy)
        end

        it 'usa BalancedSelector para selecionar agente do time' do
          expect_any_instance_of(Starchat::AutoAssignment::BalancedSelector)
            .to receive(:select_agent).and_call_original

          conversation.update!(team: team)
          expect(conversation.reload.assignee).to eq(agent)
        end
      end

      context 'com política equal_distribution' do
        before do
          policy = create(:assignment_policy,
                          account: account,
                          assignment_order: :equal_distribution,
                          equal_distribution_window_hours: 24,
                          equal_distribution_balance_threshold: 20,
                          enabled: true)
          create(:inbox_assignment_policy, inbox: inbox, assignment_policy: policy)
        end

        it 'usa EqualDistributionSelector para selecionar agente do time' do
          expect_any_instance_of(Starchat::AutoAssignment::EqualDistributionSelector)
            .to receive(:select_agent).and_call_original

          conversation.update!(team: team)
          expect(conversation.reload.assignee).to eq(agent)
        end
      end

      context 'quando nenhum agente do time está online' do
        before { OnlineStatusTracker.set_status(account.id, agent.id, 'offline') }

        it 'não atribui agente (retorna nil)' do
          conversation.update!(team: team)
          expect(conversation.reload.assignee).to be_nil
        end
      end

      context 'quando agente é do time mas não é membro da inbox' do
        let(:outsider) { create(:user, account: account, role: :agent, auto_offline: false) }

        before do
          create(:team_member, team: team, user: outsider)
          # NÃO cria inbox_member para outsider
          OnlineStatusTracker.update_presence(account.id, 'User', outsider.id)
          OnlineStatusTracker.set_status(account.id, outsider.id, 'online')
        end

        it 'não atribui agente fora da inbox' do
          # Apenas outsider está no time, mas não na inbox
          conversation.update!(team: team)
          # Pode atribuir agent (que é inbox_member) mas não outsider
          assignee = conversation.reload.assignee
          expect(assignee).not_to eq(outsider) if assignee.present?
        end
      end
    end

    context 'quando assignment_v2 está desabilitado' do
      before { account.disable_features!('assignment_v2') }

      it 'usa AgentAssignmentService (caminho legado)' do
        assignment_svc = instance_double(AutoAssignment::AgentAssignmentService, find_assignee: agent)
        expect(AutoAssignment::AgentAssignmentService).to receive(:new).with(
          conversation: conversation,
          allowed_agent_ids: array_including(agent.id)
        ).and_return(assignment_svc)
        expect(AutoAssignment::PolicyAgentSelector).not_to receive(:new)

        conversation.update!(team: team)
      end
    end
  end
end
