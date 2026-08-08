require 'rails_helper'

RSpec.describe 'Conversation Participants API', type: :request do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:agent) { create(:user, account: account, role: :agent) }

  before do
    create(:inbox_member, inbox: conversation.inbox, user: agent)
  end

  # Helper to stub the event dispatcher cleanly
  def expect_event_dispatch(event_name, user:)
    expect(Rails.configuration.dispatcher).to receive(:dispatch).with(
      event_name,
      anything,
      hash_including(conversation: conversation, user: user)
    )
  end

  def stub_dispatcher
    allow(Rails.configuration.dispatcher).to receive(:dispatch)
  end

  describe 'GET /api/v1/accounts/{account.id}/conversations/<id>/paricipants' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get api_v1_account_conversation_participants_url(account_id: account.id, conversation_id: conversation.display_id)
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user with access to the conversation' do
      let(:participant1) { create(:user, account: account, role: :agent) }
      let(:participant2) { create(:user, account: account, role: :agent) }

      before do
        create(:inbox_member, inbox: conversation.inbox, user: participant1)
        create(:inbox_member, inbox: conversation.inbox, user: participant2)
      end

      it 'returns all the partipants for the conversation' do
        create(:conversation_participant, conversation: conversation, user: participant1)
        create(:conversation_participant, conversation: conversation, user: participant2)
        get api_v1_account_conversation_participants_url(account_id: account.id, conversation_id: conversation.display_id),
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(response.body).to include(participant1.email)
        expect(response.body).to include(participant2.email)
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/conversations/<id>/participants' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post api_v1_account_conversation_participants_url(account_id: account.id, conversation_id: conversation.display_id)
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:participant) { create(:user, account: account, role: :agent) }

      before do
        create(:inbox_member, inbox: conversation.inbox, user: participant)
      end

      it 'creates a new participants when its authorized agent' do
        params = { user_ids: [participant.id] }

        expect(conversation.conversation_participants.count).to eq(0)
        post api_v1_account_conversation_participants_url(account_id: account.id, conversation_id: conversation.display_id),
             params: params,
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        expect(response.body).to include(participant.email)
        expect(conversation.conversation_participants.count).to eq(1)
      end

      it 'dispatches CONVERSATION_PARTICIPANT_ADDED event for the new participant' do
        expect_event_dispatch(Events::Types::CONVERSATION_PARTICIPANT_ADDED, user: participant)

        post api_v1_account_conversation_participants_url(account_id: account.id, conversation_id: conversation.display_id),
             params: { user_ids: [participant.id] },
             headers: agent.create_new_auth_token,
             as: :json
      end

      it 'does not dispatch event for already-existing participant (idempotent)' do
        create(:conversation_participant, conversation: conversation, user: participant)

        expect(Rails.configuration.dispatcher).not_to receive(:dispatch).with(
          Events::Types::CONVERSATION_PARTICIPANT_ADDED, anything, anything
        )

        post api_v1_account_conversation_participants_url(account_id: account.id, conversation_id: conversation.display_id),
             params: { user_ids: [participant.id] },
             headers: agent.create_new_auth_token,
             as: :json
      end

      it 'dispatches event for each participant when multiple are added' do
        extra_participant = create(:user, account: account, role: :agent)
        create(:inbox_member, inbox: conversation.inbox, user: extra_participant)

        expect_event_dispatch(Events::Types::CONVERSATION_PARTICIPANT_ADDED, user: participant)
        expect_event_dispatch(Events::Types::CONVERSATION_PARTICIPANT_ADDED, user: extra_participant)

        post api_v1_account_conversation_participants_url(account_id: account.id, conversation_id: conversation.display_id),
             params: { user_ids: [participant.id, extra_participant.id] },
             headers: agent.create_new_auth_token,
             as: :json
end

      it 'notifies unread counts when a participant is added' do
        account.enable_features!(:conversation_unread_counts, :unread_count_for_filters)
        allow(Rails.configuration.dispatcher).to receive(:dispatch)
        params = { user_ids: [participant.id] }

        post api_v1_account_conversation_participants_url(account_id: account.id, conversation_id: conversation.display_id),
             params: params,
             headers: agent.create_new_auth_token,
             as: :json

        expect(Rails.configuration.dispatcher).to have_received(:dispatch).with(
          'conversation.unread_count_changed',
          kind_of(ActiveSupport::TimeWithZone),
          conversation: conversation
        )
      end
    end
  end

  describe 'PUT /api/v1/accounts/{account.id}/conversations/<id>/participants' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        put api_v1_account_conversation_participants_url(account_id: account.id, conversation_id: conversation.display_id)
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:participant) { create(:user, account: account, role: :agent) }
      let(:participant_to_be_added) { create(:user, account: account, role: :agent) }
      let(:participant_to_be_removed) { create(:user, account: account, role: :agent) }

      before do
        create(:inbox_member, inbox: conversation.inbox, user: participant)
        create(:inbox_member, inbox: conversation.inbox, user: participant_to_be_added)
        create(:inbox_member, inbox: conversation.inbox, user: participant_to_be_removed)
      end

      it 'updates participants when its authorized agent' do
        params = { user_ids: [participant.id, participant_to_be_added.id] }
        create(:conversation_participant, conversation: conversation, user: participant)
        create(:conversation_participant, conversation: conversation, user: participant_to_be_removed)

        expect(conversation.conversation_participants.count).to eq(2)
        stub_dispatcher
        put api_v1_account_conversation_participants_url(account_id: account.id, conversation_id: conversation.display_id),
            params: params,
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(response.body).to include(participant.email)
        expect(response.body).to include(participant_to_be_added.email)
        expect(conversation.conversation_participants.count).to eq(2)
      end

      it 'dispatches CONVERSATION_PARTICIPANT_ADDED for newly added participant' do
        create(:conversation_participant, conversation: conversation, user: participant)
        create(:conversation_participant, conversation: conversation, user: participant_to_be_removed)
        stub_dispatcher

        expect(Rails.configuration.dispatcher).to receive(:dispatch).with(
          Events::Types::CONVERSATION_PARTICIPANT_ADDED,
          anything,
          hash_including(conversation: conversation, user: participant_to_be_added)
        )

        put api_v1_account_conversation_participants_url(account_id: account.id, conversation_id: conversation.display_id),
            params: { user_ids: [participant.id, participant_to_be_added.id] },
            headers: agent.create_new_auth_token,
            as: :json
      end

      it 'dispatches CONVERSATION_PARTICIPANT_REMOVED for removed participant' do
        create(:conversation_participant, conversation: conversation, user: participant)
        create(:conversation_participant, conversation: conversation, user: participant_to_be_removed)
        stub_dispatcher

        expect(Rails.configuration.dispatcher).to receive(:dispatch).with(
          Events::Types::CONVERSATION_PARTICIPANT_REMOVED,
          anything,
          hash_including(conversation: conversation, user: participant_to_be_removed)
        )

        put api_v1_account_conversation_participants_url(account_id: account.id, conversation_id: conversation.display_id),
            params: { user_ids: [participant.id, participant_to_be_added.id] },
            headers: agent.create_new_auth_token,
            as: :json
      end

      it 'does not dispatch CONVERSATION_PARTICIPANT_REMOVED for participants that stay' do
        create(:conversation_participant, conversation: conversation, user: participant)
        create(:conversation_participant, conversation: conversation, user: participant_to_be_removed)
        allow(Rails.configuration.dispatcher).to receive(:dispatch)

        expect(Rails.configuration.dispatcher).not_to receive(:dispatch).with(
          Events::Types::CONVERSATION_PARTICIPANT_REMOVED,
          anything,
          hash_including(user: participant)
        )

        put api_v1_account_conversation_participants_url(account_id: account.id, conversation_id: conversation.display_id),
            params: { user_ids: [participant.id, participant_to_be_added.id] },
            headers: agent.create_new_auth_token,
            as: :json
      end

      context 'when removed participant is also the conversation assignee' do
        before do
          conversation.update!(assignee: participant_to_be_removed)
          create(:conversation_participant, conversation: conversation, user: participant)
          create(:conversation_participant, conversation: conversation, user: participant_to_be_removed)
        end

        it 'still dispatches CONVERSATION_PARTICIPANT_REMOVED event' do
          stub_dispatcher

          expect(Rails.configuration.dispatcher).to receive(:dispatch).with(
            Events::Types::CONVERSATION_PARTICIPANT_REMOVED,
            anything,
            hash_including(conversation: conversation, user: participant_to_be_removed)
          )

          put api_v1_account_conversation_participants_url(account_id: account.id, conversation_id: conversation.display_id),
              params: { user_ids: [participant.id] },
              headers: agent.create_new_auth_token,
              as: :json
        end
end

      it 'notifies unread counts when participant membership changes' do
        account.enable_features!(:conversation_unread_counts, :unread_count_for_filters)
        allow(Rails.configuration.dispatcher).to receive(:dispatch)
        params = { user_ids: [participant.id, participant_to_be_added.id] }
        create(:conversation_participant, conversation: conversation, user: participant)
        create(:conversation_participant, conversation: conversation, user: participant_to_be_removed)

        put api_v1_account_conversation_participants_url(account_id: account.id, conversation_id: conversation.display_id),
            params: params,
            headers: agent.create_new_auth_token,
            as: :json

        expect(Rails.configuration.dispatcher).to have_received(:dispatch).with(
          'conversation.unread_count_changed',
          kind_of(ActiveSupport::TimeWithZone),
          conversation: conversation
        )
      end
    end
  end

  describe 'DELETE /api/v1/accounts/{account.id}/conversations/<id>/participants' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        delete api_v1_account_conversation_participants_url(account_id: account.id, conversation_id: conversation.display_id)
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:participant) { create(:user, account: account, role: :agent) }

      before do
        create(:inbox_member, inbox: conversation.inbox, user: participant)
      end

      it 'deletes participants when its authorized agent' do
        params = { user_ids: [participant.id] }
        create(:conversation_participant, conversation: conversation, user: participant)

        expect(conversation.conversation_participants.count).to eq(1)
        stub_dispatcher
        delete api_v1_account_conversation_participants_url(account_id: account.id, conversation_id: conversation.display_id),
               params: params,
               headers: agent.create_new_auth_token,
               as: :json

        expect(response).to have_http_status(:success)
        expect(conversation.conversation_participants.count).to eq(0)
      end

      it 'dispatches CONVERSATION_PARTICIPANT_REMOVED event for each deleted participant' do
        extra_participant = create(:user, account: account, role: :agent)
        create(:inbox_member, inbox: conversation.inbox, user: extra_participant)
        create(:conversation_participant, conversation: conversation, user: participant)
        create(:conversation_participant, conversation: conversation, user: extra_participant)

        expect_event_dispatch(Events::Types::CONVERSATION_PARTICIPANT_REMOVED, user: participant)
        expect_event_dispatch(Events::Types::CONVERSATION_PARTICIPANT_REMOVED, user: extra_participant)

        delete api_v1_account_conversation_participants_url(account_id: account.id, conversation_id: conversation.display_id),
               params: { user_ids: [participant.id, extra_participant.id] },
               headers: agent.create_new_auth_token,
               as: :json
      end

      it 'does not dispatch event for user_ids that were not actual participants' do
        non_participant = create(:user, account: account, role: :agent)
        create(:inbox_member, inbox: conversation.inbox, user: non_participant)
        create(:conversation_participant, conversation: conversation, user: participant)

        expect_event_dispatch(Events::Types::CONVERSATION_PARTICIPANT_REMOVED, user: participant)
        expect(Rails.configuration.dispatcher).not_to receive(:dispatch).with(
          Events::Types::CONVERSATION_PARTICIPANT_REMOVED,
          anything,
          hash_including(user: non_participant)
        )

        delete api_v1_account_conversation_participants_url(account_id: account.id, conversation_id: conversation.display_id),
               params: { user_ids: [participant.id, non_participant.id] },
               headers: agent.create_new_auth_token,
               as: :json
      end

      context 'when removed participant is also the conversation assignee' do
        before do
          conversation.update!(assignee: participant)
          create(:conversation_participant, conversation: conversation, user: participant)
        end

        it 'still dispatches CONVERSATION_PARTICIPANT_REMOVED (frontend decides visibility based on assignee)' do
          expect_event_dispatch(Events::Types::CONVERSATION_PARTICIPANT_REMOVED, user: participant)

          delete api_v1_account_conversation_participants_url(account_id: account.id, conversation_id: conversation.display_id),
                 params: { user_ids: [participant.id] },
                 headers: agent.create_new_auth_token,
                 as: :json
        end
end

      it 'notifies unread counts when a participant is removed' do
        account.enable_features!(:conversation_unread_counts, :unread_count_for_filters)
        allow(Rails.configuration.dispatcher).to receive(:dispatch)
        params = { user_ids: [participant.id] }
        create(:conversation_participant, conversation: conversation, user: participant)

        delete api_v1_account_conversation_participants_url(account_id: account.id, conversation_id: conversation.display_id),
               params: params,
               headers: agent.create_new_auth_token,
               as: :json

        expect(Rails.configuration.dispatcher).to have_received(:dispatch).with(
          'conversation.unread_count_changed',
          kind_of(ActiveSupport::TimeWithZone),
          conversation: conversation
        )
      end
    end
  end
end
