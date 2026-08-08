require 'rails_helper'

RSpec.describe Cosmos::Conversation::ResponseBuilderJob, type: :job do
  let(:account) { create(:account, custom_attributes: { plan_name: 'startups' }) }
  let(:inbox) { create(:inbox, account: account) }
  let(:assistant) { create(:cosmos_assistant, account: account) }
  let(:cosmos_inbox_association) { create(:cosmos_inbox, cosmos_assistant: assistant, inbox: inbox) }

  describe '#perform' do
    let(:conversation) { create(:conversation, inbox: inbox, account: account, status: :pending) }
    let(:mock_llm_chat_service) { instance_double(Cosmos::Llm::AssistantChatService) }
    let(:mock_agent_runner_service) { instance_double(Cosmos::Assistant::AgentRunnerService) }
    let(:mock_action_classifier_service) { instance_double(Cosmos::Llm::AssistantActionClassifierService) }
    let(:mock_false_promise_service) { instance_double(Cosmos::Llm::AssistantFalsePromiseService) }
    let(:assistant_model) { Llm::Models.default_model_for('assistant') }

    before do
      create(:message, conversation: conversation, content: 'Hello', message_type: :incoming)

      allow(inbox).to receive(:cosmos_active?).and_return(true)
      allow(Cosmos::Llm::AssistantChatService).to receive(:new).and_return(mock_llm_chat_service)
      allow(mock_llm_chat_service).to receive(:generate_response).and_return({ 'response' => 'Hey, welcome to cosmos Specs' })
      allow(Cosmos::Assistant::AgentRunnerService).to receive(:new).and_return(mock_agent_runner_service)
      allow(mock_agent_runner_service).to receive(:generate_response).and_return({ 'response' => 'Hey, welcome to Cosmos V2' })
      allow(mock_agent_runner_service).to receive(:last_run_result).and_return(nil)
      allow(Cosmos::Llm::AssistantActionClassifierService).to receive(:new).and_return(mock_action_classifier_service)
      allow(mock_action_classifier_service).to receive(:classify).and_return({ 'action' => 'continue' })
      allow(Cosmos::Llm::AssistantFalsePromiseService).to receive(:new).and_return(mock_false_promise_service)
      allow(mock_false_promise_service).to receive(:detect).and_return({ 'decision' => 'safe', 'reason' => 'safe_response' })
    end

    context 'when Cosmos_v2 is disabled' do
      before do
        allow(account).to receive(:feature_enabled?).and_return(false)
        allow(account).to receive(:feature_enabled?).with('cosmos_integration_v2').and_return(false)
      end

      it 'uses Cosmos::Llm::AssistantChatService' do
        expect(Cosmos::Llm::AssistantChatService).to receive(:new).with(assistant: assistant)
        expect(Cosmos::Assistant::AgentRunnerService).not_to receive(:new)

        described_class.perform_now(conversation, assistant)
        expect(conversation.messages.last.content).to eq('Hey, welcome to cosmos Specs')
      end

      it 'generates and processes response' do
        described_class.perform_now(conversation, assistant)
        expect(conversation.messages.count).to eq(2)
        expect(conversation.messages.outgoing.count).to eq(1)
        expect(conversation.messages.last.content).to eq('Hey, welcome to cosmos Specs')
      end

      it 'keeps the default message history limited to public chat messages' do
        create(
          :message,
          conversation: conversation,
          message_type: :activity,
          content: 'Conversation was marked resolved',
          content_attributes: { activity: { type: 'conversation_status_changed', status: 'resolved' } }
        )
        create(:message, conversation: conversation, content: 'Private note', message_type: :outgoing, private: true)

        expect(mock_llm_chat_service).to receive(:generate_response).with(
          message_history: [{ content: 'Hello', role: 'user' }]
        ).and_return({ 'response' => 'Hey, welcome to Cosmos Specs' })

        described_class.perform_now(conversation, assistant)
      end

      it 'increments usage response' do
        described_class.perform_now(conversation, assistant)
        account.reload
        expect(account.usage_limits[:cosmos][:responses][:consumed]).to eq(1)
      end

      context 'when message contains an image' do
        let(:message_with_image) { create(:message, conversation: conversation, message_type: :incoming, content: 'Can you help with this error?') }
        let(:image_attachment) { message_with_image.attachments.create!(account: account, file_type: :image, external_url: 'https://example.com/error.jpg') }
end

      it 'does not create a cosmos session' do
        expect do
          described_class.perform_now(conversation, assistant)
        end.not_to change(Cosmos::AgentSession, :count)
      end

      it 'does not run the action classifier when the classifier feature is disabled' do
        expect(Cosmos::Llm::AssistantActionClassifierService).not_to receive(:new)

        described_class.perform_now(conversation, assistant)

        expect(conversation.messages.last.content).to eq('Hey, welcome to Cosmos Specs')
      end

      it 'does not run the false promise harness when the account setting is disabled' do
        expect(Cosmos::Llm::AssistantFalsePromiseService).not_to receive(:new)

        described_class.perform_now(conversation, assistant)

        expect(conversation.messages.last.content).to eq('Hey, welcome to Cosmos Specs')
      end

      context 'when false promise harness is enabled in account settings' do
        before do
          account.update!(settings: account.settings.merge('cosmos_false_promise_harness_enabled' => true))
        end

        it 'sends the original response when the detector marks it safe' do
          expect(mock_false_promise_service).to receive(:detect).with(
            message_history: [{ content: 'Hello', role: 'user' }],
            assistant_response: 'Hey, welcome to Cosmos Specs'
          ).and_return({
                         'decision' => 'safe',
                         'reason' => 'safe_response',
                         'model' => assistant_model
                       })

          described_class.perform_now(conversation, assistant)

          expect(conversation.reload.status).to eq('pending')
          expect(conversation.messages.outgoing.last.content).to eq('Hey, welcome to Cosmos Specs')
          expect(account.reload.usage_limits[:cosmos][:responses][:consumed]).to eq(1)
        end

        it 'regenerates future-work promises through the V1 assistant chat service' do
          allow(mock_llm_chat_service).to receive(:generate_response)
            .and_return(
              { 'response' => 'Let me check the documentation and get back to you.' },
              { 'response' => 'Could you share the exact error message you see?' }
            )
          allow(mock_false_promise_service).to receive(:detect)
            .and_return(
              {
                'decision' => 'future_work_promise',
                'reason' => 'future_check_or_investigation',
                'model' => assistant_model
              },
              {
                'decision' => 'safe',
                'reason' => 'asks_user_to_check_or_provide_info',
                'model' => assistant_model
              }
            )

          described_class.perform_now(conversation, assistant)

          expect(conversation.reload.status).to eq('pending')
          expect(conversation.messages.outgoing.last.content).to eq('Could you share the exact error message you see?')
          expect(account.reload.usage_limits[:cosmos][:responses][:consumed]).to eq(1)
          expect(mock_llm_chat_service).to have_received(:generate_response).with(
            message_history: [{ content: 'Hello', role: 'user' }]
          )
          expect(mock_llm_chat_service).to have_received(:generate_response).with(
            message_history: [
              { content: 'Hello', role: 'user' },
              { role: 'assistant', content: 'Let me check the documentation and get back to you.' }
            ],
            additional_message: Cosmos::Conversation::V1FalsePromiseHandler::FUTURE_PROMISE_REPAIR_INSTRUCTION
          )
        end

        it 'hands off instead of sending the unsafe draft when repair generation fails' do
          allow(mock_llm_chat_service).to receive(:generate_response)
            .and_return({ 'response' => 'Let me check and get back to you.' })
          allow(mock_llm_chat_service).to receive(:generate_response)
            .with(
              message_history: [
                { content: 'Hello', role: 'user' },
                { role: 'assistant', content: 'Let me check and get back to you.' }
              ],
              additional_message: Cosmos::Conversation::V1FalsePromiseHandler::FUTURE_PROMISE_REPAIR_INSTRUCTION
            ).and_raise(StandardError, 'repair timeout')
          allow(mock_false_promise_service).to receive(:detect).and_return({
                                                                             'decision' => 'future_work_promise',
                                                                             'reason' => 'future_check_or_investigation',
                                                                             'model' => assistant_model
                                                                           })

          described_class.perform_now(conversation, assistant)

          expect(conversation.reload.status).to eq('open')
          expect(conversation.messages.outgoing.last.content).to eq(I18n.t('conversations.cosmos.handoff'))
          expect(conversation.messages.outgoing.pluck(:content)).not_to include('Let me check and get back to you.')
          expect(account.reload.usage_limits[:cosmos][:responses][:consumed]).to eq(0)
        end

        it 'hands off instead of sending an unverified repair when repair verification is inconclusive' do
          allow(mock_llm_chat_service).to receive(:generate_response)
            .and_return(
              { 'response' => 'Let me check and get back to you.' },
              { 'response' => 'Could you share the exact error message you see?' }
            )
          allow(mock_false_promise_service).to receive(:detect)
            .and_return(
              {
                'decision' => 'future_work_promise',
                'reason' => 'future_check_or_investigation',
                'model' => assistant_model
              },
              {
                'decision' => nil,
                'reason' => nil,
                'error' => 'verification timeout',
                'model' => assistant_model
              }
            )

          described_class.perform_now(conversation, assistant)

          expect(conversation.reload.status).to eq('open')
          expect(conversation.messages.outgoing.last.content).to eq(I18n.t('conversations.cosmos.handoff'))
          expect(conversation.messages.outgoing.pluck(:content)).not_to include('Could you share the exact error message you see?')
          expect(account.reload.usage_limits[:cosmos][:responses][:consumed]).to eq(0)
        end

        it 'hands off when the regenerated response still contains a future-work promise' do
          allow(mock_llm_chat_service).to receive(:generate_response)
            .and_return(
              { 'response' => 'Let me check and get back to you.' },
              { 'response' => 'I will monitor this and update you later.' }
            )
          allow(mock_false_promise_service).to receive(:detect).and_return({
                                                                             'decision' => 'future_work_promise',
                                                                             'reason' => 'future_check_or_investigation',
                                                                             'model' => assistant_model
                                                                           })

          described_class.perform_now(conversation, assistant)

          expect(conversation.reload.status).to eq('open')
          expect(conversation.messages.outgoing.last.content).to eq(I18n.t('conversations.cosmos.handoff'))
          expect(account.reload.usage_limits[:cosmos][:responses][:consumed]).to eq(0)
        end

        it 'skips the false promise harness when the action classifier already requested handoff' do
          allow(account).to receive(:feature_enabled?).and_return(false)
          allow(account).to receive(:feature_enabled?).with('cosmos_integration_v2').and_return(false)
          allow(account).to receive(:feature_enabled?).with('cosmos_v1_action_classifier').and_return(true)
          allow(mock_action_classifier_service).to receive(:classify).and_return({
                                                                                   'action' => 'handoff',
                                                                                   'action_reason' => 'explicit_human_request',
                                                                                   'model' => 'gpt-4.1'
                                                                                 })

          expect(Cosmos::Llm::AssistantFalsePromiseService).not_to receive(:new)

          described_class.perform_now(conversation, assistant)

          expect(conversation.reload.status).to eq('open')
          expect(conversation.messages.outgoing.last.content).to eq(I18n.t('conversations.cosmos.handoff'))
        end
      end

      context 'when V1 action classifier is enabled' do
        before do
          image_attachment
        end

        it 'includes image URL directly in the message content for OpenAI vision analysis' do
          # Expect the generate_response to receive multimodal content with image URL
          expect(mock_llm_chat_service).to receive(:generate_response) do |**kwargs|
            history = kwargs[:message_history]
            last_entry = history.last
            expect(last_entry[:content]).to be_an(Array)
            expect(last_entry[:content].any? { |part| part[:type] == 'text' && part[:text] == 'Can you help with this error?' }).to be true
            expect(last_entry[:content].any? do |part|
              part[:type] == 'image_url' && part[:image_url][:url] == 'https://example.com/error.jpg'
            end).to be true
            { 'response' => 'I can see the error in your image. It appears to be a database connection issue.' }
          end

          described_class.perform_now(conversation, assistant)
        end
      end
    end

    describe 'retry mechanisms for image processing' do
      let(:conversation) { create(:conversation, inbox: inbox, account: account, status: :pending) }
      let(:mock_llm_chat_service) { instance_double(Cosmos::Llm::AssistantChatService) }
      let(:mock_message_builder) { instance_double(Cosmos::OpenAiMessageBuilderService) }

      before do
        create(:message, conversation: conversation, content: 'Hello with image', message_type: :incoming)
        allow(account).to receive(:feature_enabled?).and_call_original
        allow(account).to receive(:feature_enabled?).with('cosmos_integration_v2').and_return(false)
        allow(account).to receive(:feature_enabled?).with('cosmos_v1_action_classifier').and_return(false)
        allow(Cosmos::Llm::AssistantChatService).to receive(:new).and_return(mock_llm_chat_service)
        allow(Cosmos::OpenAiMessageBuilderService).to receive(:new).with(message: anything).and_return(mock_message_builder)
        allow(mock_message_builder).to receive(:generate_content).and_return('Hello with image')
        allow(mock_llm_chat_service).to receive(:generate_response).and_return({ 'response' => 'Test response' })
      end

      context 'when ActiveStorage::FileNotFoundError occurs' do
        it 'handles file errors and triggers handoff' do
          allow(mock_message_builder).to receive(:generate_content)
            .and_raise(ActiveStorage::FileNotFoundError, 'Image file not found')

          # For retryable errors, the job should handle them and proceed with handoff
          described_class.perform_now(conversation, assistant)

          # Verify handoff occurred due to repeated failures
          expect(conversation.reload.status).to eq('open')
        end

        it 'succeeds when no error occurs' do
          # Don't raise any error, should succeed normally
          allow(mock_message_builder).to receive(:generate_content)
            .and_return('Image content processed successfully')

          described_class.perform_now(conversation, assistant)

          expect(conversation.messages.outgoing.count).to eq(1)
          expect(conversation.messages.outgoing.last.content).to eq('Test response')
        end
      end

      context 'when Faraday::BadRequestError occurs' do
        it 'handles API errors and triggers handoff' do
          allow(mock_llm_chat_service).to receive(:generate_response)
            .and_raise(Faraday::BadRequestError, 'Bad request to image service')

          described_class.perform_now(conversation, assistant)
          expect(conversation.reload.status).to eq('open')
        end.not_to(change { conversation.messages.outgoing.count })
      end
    end

    context 'when cosmos_v2 is enabled' do
      before do
        allow(account).to receive(:feature_enabled?).and_return(false)
        allow(account).to receive(:feature_enabled?).with('cosmos_integration_v2').and_return(true)
      end

      it 'uses Cosmos::Assistant::AgentRunnerService' do
        expect(Cosmos::Assistant::AgentRunnerService).to receive(:new).with(
          assistant: assistant,
          conversation: conversation
        )
        expect(Cosmos::Llm::AssistantChatService).not_to receive(:new)

        described_class.perform_now(conversation, assistant)
        expect(conversation.messages.last.content).to eq('Hey, welcome to Cosmos V2')
      end

      it 'passes message history with resolution markers to agent runner service' do
        same_second = Time.current.change(usec: 0)
        conversation.messages.find_by!(content: 'Hello').update!(created_at: same_second, updated_at: same_second)
        create(
          :message,
          conversation: conversation,
          message_type: :activity,
          content: 'Conversation was marked resolved by Alice',
          content_attributes: { activity: { type: 'conversation_status_changed', status: 'resolved' } },
          created_at: same_second,
          updated_at: same_second
        )
        create(:message, conversation: conversation, message_type: :activity, content: 'Assigned to agent', created_at: same_second,
                         updated_at: same_second)
        create(:message, conversation: conversation, content: 'Fresh question', message_type: :incoming, created_at: same_second,
                         updated_at: same_second)

        expected_messages = [
          { content: 'Hello', role: 'user' },
          {
            content: Cosmos::Conversation::MessageHistoryBuilderService::RESOLUTION_MARKER,
            role: 'assistant'
          },
          { content: 'Fresh question', role: 'user' }
        ]

        expect(mock_agent_runner_service).to receive(:generate_response).with(
          message_history: expected_messages
        )

        described_class.perform_now(conversation, assistant)
      end

      it 'generates and processes response' do
        described_class.perform_now(conversation, assistant)
        expect(conversation.messages.count).to eq(2)
        expect(conversation.messages.outgoing.count).to eq(1)
        expect(conversation.messages.last.content).to eq('Hey, welcome to Cosmos V2')
      end

      it 'increments usage response' do
        described_class.perform_now(conversation, assistant)
        account.reload
        expect(account.usage_limits[:cosmos][:responses][:consumed]).to eq(1)
      end
    end

    context 'when cosmos_v2 handoff tool fires during agent execution' do
      before do
        allow(account).to receive(:feature_enabled?).and_return(false)
        allow(account).to receive(:feature_enabled?).with('cosmos_integration_v2').and_return(true)
      end

      it 'creates a public handoff message visible to the customer' do
        allow(mock_agent_runner_service).to receive(:generate_response) do
          conversation.update!(status: :open)
          { 'response' => 'Let me connect you', 'handoff_tool_called' => true }
        end

        it 'succeeds when no error occurs' do
          # Don't raise any error, should succeed normally
          allow(mock_llm_chat_service).to receive(:generate_response)
            .and_return({ 'response' => 'Response after retry' })

          described_class.perform_now(conversation, assistant)

          expect(conversation.messages.outgoing.last.content).to eq('Response after retry')
        end
      end

      context 'when image processing fails permanently' do
        before do
          allow(mock_message_builder).to receive(:generate_content)
            .and_raise(ActiveStorage::FileNotFoundError, 'Image permanently unavailable')
        end

        it 'triggers handoff after max retries' do
          # Since perform_now re-raises retryable errors, simulate the final failure after retries
          allow(mock_message_builder).to receive(:generate_content)
            .and_raise(StandardError, 'Max retries exceeded')

          expect(ChatwootExceptionTracker).to receive(:new).and_call_original

          described_class.perform_now(conversation, assistant)

          expect(conversation.reload.status).to eq('open')
        end

        described_class.perform_now(conversation, assistant)

        expect(conversation.reload.waiting_since).to be_within(1.second).of(original_waiting_since)
      end

      it 'does not hand off when handoff_tool_called is false' do
        allow(mock_agent_runner_service).to receive(:generate_response).and_return({
                                                                                     'response' => 'Hi! How can I help you?',
                                                                                     'handoff_tool_called' => false
                                                                                   })

        described_class.perform_now(conversation, assistant)

        expect(conversation.messages.outgoing.count).to eq(1)
        expect(conversation.messages.last.content).to eq('Hi! How can I help you?')
        expect(conversation.reload.status).to eq('pending')
      end

      it 'falls back to a full V1 handoff when HandoffTool fired but failed to commit' do
        allow(mock_agent_runner_service).to receive(:generate_response).and_return({
                                                                                     'response' => 'I tried to hand off',
                                                                                     'handoff_tool_called' => true
                                                                                   })

        described_class.perform_now(conversation, assistant)

        conversation.reload
        expect(conversation.status).to eq('open')
        public_messages = conversation.messages.outgoing.where(private: false)
        expect(public_messages.count).to eq(1)
        expect(public_messages.last.content).to eq(I18n.t('conversations.cosmos.handoff'))
      end
    end

    context 'when capturing assistant sessions' do
      let(:run_context) do
        {
          session_id: "#{account.id}_#{conversation.display_id}",
          current_agent: 'Assistant',
          turn_count: 1,
          conversation_history: [
            { role: :user, content: 'Hello' },
            { role: :assistant, content: 'Hey, welcome to Cosmos V2', agent_name: 'Assistant' }
          ],
          state: { cw_metadata: { faq_ids: [7, 9], document_ids: [3] } }
        }
      end
      let(:usage) do
        Agents::RunContext::Usage.new.tap do |u|
          u.input_tokens = 100
          u.output_tokens = 20
          u.total_tokens = 120
        end
      end
      let(:run_result) { Agents::RunResult.new(output: { 'response' => 'Hey, welcome to Cosmos V2' }, usage: usage, context: run_context) }

      before do
        allow(account).to receive(:feature_enabled?).and_return(false)
        allow(account).to receive(:feature_enabled?).with('cosmos_integration_v2').and_return(true)
        allow(mock_agent_runner_service).to receive(:last_run_result).and_return(run_result)
      end

      it 'creates a session for a delivered response' do
        described_class.perform_now(conversation, assistant)

        session = Cosmos::AgentSession.last
        expect(session).to have_attributes(
          account_id: account.id,
          assistant_id: assistant.id,
          subject_id: conversation.id,
          subject_type: 'Conversation',
          result_id: conversation.messages.outgoing.last.id,
          result_type: 'Message',
          llm_model: 'openai-gpt-5.2',
          credits_consumed: 1.0,
          faq_ids: [7, 9],
          document_ids: [3],
          scenario_ids: [],
          user_id: nil
        )
        expect(session).to be_session_assistant
        expect(session.run_context.first).to include('role' => 'user', 'content' => 'Hello')
      end

      it 'creates a zero-credit session when the handoff tool fired' do
        allow(mock_agent_runner_service).to receive(:generate_response) do
          conversation.update!(status: :open)
          { 'response' => 'Let me connect you', 'handoff_tool_called' => true }
        end

        described_class.perform_now(conversation, assistant)

        session = Cosmos::AgentSession.last
        expect(session.credits_consumed).to eq(0.0)
        expect(session.result_id).to eq(conversation.messages.outgoing.where(private: false).last.id)
        expect(account.reload.usage_limits[:cosmos][:responses][:consumed]).to eq(0)
      end

      it 'attributes the handoff session to the private reason note when the tool recorded one' do
        handoff_note = create(:message, conversation: conversation, account: account, message_type: :outgoing,
                                        private: true, sender: assistant, content: 'Needs a human')
        run_context[:state][:cw_metadata][:handoff_note_id] = handoff_note.id
        allow(mock_agent_runner_service).to receive(:generate_response) do
          conversation.update!(status: :open)
          { 'response' => 'Let me connect you', 'handoff_tool_called' => true }
        end

        described_class.perform_now(conversation, assistant)

        session = Cosmos::AgentSession.last
        expect(session.credits_consumed).to eq(0.0)
        expect(session.result_id).to eq(handoff_note.id)
      end

      it 'creates a zero-credit session when the handoff tool fired but failed to commit' do
        allow(mock_agent_runner_service).to receive(:generate_response).and_return({
                                                                                     'response' => 'I tried to hand off',
                                                                                     'handoff_tool_called' => true
                                                                                   })

        described_class.perform_now(conversation, assistant)

        session = Cosmos::AgentSession.last
        expect(session.credits_consumed).to eq(0.0)
        expect(session.result_id).to eq(conversation.messages.outgoing.where(private: false).last.id)
      end

      it 'still delivers the reply when session capture fails' do
        allow(Cosmos::AgentSession).to receive(:create!).and_raise(StandardError, 'capture failed')
        allow(ChatwootExceptionTracker).to receive(:new).and_call_original

        expect do
          described_class.perform_now(conversation, assistant)
        end.not_to raise_error

        expect(conversation.messages.outgoing.count).to eq(1)
        expect(conversation.messages.outgoing.last.content).to eq('Hey, welcome to Cosmos V2')
        expect(conversation.reload.status).to eq('pending')
        expect(ChatwootExceptionTracker).to have_received(:new)
      end
    end

    # Regression (PR #13417): wrapping create_handoff_message and bot_handoff! in the
    # same transaction defers the message's after_create_commit until commit, at which
    # point it clears waiting_since (bot_response). The handoff path must stay outside
    # the transaction so the callback fires before bot_handoff! sets waiting_since.
    context 'when handoff is requested' do
      let(:conversation) { create(:conversation, inbox: inbox, account: account, status: :pending) }
      let(:agent) { create(:user, account: account, role: :agent) }

      before do
        allow(account).to receive(:feature_enabled?).and_return(false)
        allow(account).to receive(:feature_enabled?).with('cosmos_integration_v2').and_return(false)
        allow(mock_llm_chat_service).to receive(:generate_response).and_return({ 'response' => 'conversation_handoff' })
      end

      it 'sets waiting_since to approximately the handoff time' do
        # Don't use freeze_time here: we need a real gap between the seeded waiting_since
        # and Time.current, otherwise "preserved" and "reset" both look identical.
        conversation.update!(waiting_since: 10.minutes.ago)

        described_class.perform_now(conversation, assistant)

        conversation.reload
        expect(conversation.status).to eq('open')
        expect(conversation.waiting_since).to be_within(5.seconds).of(Time.current)
      end

      it 'preserves waiting_since so a human reply consumes it for reply_time tracking' do
        described_class.perform_now(conversation, assistant)

        conversation.reload
        expect(conversation.waiting_since).to be_present

        # A human reply clears waiting_since (consumed by dispatch_create_events
        # to emit FIRST_REPLY_CREATED or REPLY_CREATED for reply_time tracking).
        create(:message, conversation: conversation, message_type: :outgoing,
                         sender: agent, account: account, inbox: inbox)
        expect(conversation.reload.waiting_since).to be_nil
      end

      context 'when non-retryable error occurs' do
        let(:standard_error) { StandardError.new('Generic error') }

        before do
          allow(mock_llm_chat_service).to receive(:generate_response).and_raise(standard_error)
        end

        it 'handles error and triggers handoff' do
          expect(ChatwootExceptionTracker).to receive(:new)
            .with(standard_error, account: account)
            .and_call_original

          described_class.perform_now(conversation, assistant)

          expect(conversation.reload.status).to eq('open')
        end

        it 'ensures Current.executed_by is reset' do
          expect(Current).to receive(:executed_by=).with(assistant)
          expect(Current).to receive(:executed_by=).with(nil)

          described_class.perform_now(conversation, assistant)
        end
      end
    end

    describe 'job configuration' do
      it 'has retry_on configuration for retryable errors' do
        expect(described_class).to respond_to(:retry_on)
      end

      it 'defines MAX_MESSAGE_LENGTH constant' do
        expect(described_class::MAX_MESSAGE_LENGTH).to eq(10_000)
      end
    end
  end
end
