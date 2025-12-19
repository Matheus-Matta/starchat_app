require 'rails_helper'

describe Messages::MessageBuilder do
  subject(:message_builder) { described_class.new(user, conversation, params).perform }

  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, inbox: inbox, account: account) }
  let(:params) { ActionController::Parameters.new({ content: 'test message' }) }

  describe '#perform anti-spam check' do
    before do
      # Mock Redis connection to avoid real Redis dependency in tests or ensure clean state
      # Using standard RSpec mocks for Redis calls inside $alfred.with
      allow($alfred).to receive(:with).and_yield(MockRedis.new)
    end

    context 'when anti-spam is disabled' do
      before do
        inbox.update(anti_spam_config: { active: false })
      end

      it 'does not block repeated messages' do
        3.times { described_class.new(user, conversation, params).perform }
        message = described_class.new(user, conversation, params).perform
        expect(message.status).to eq('sent').or eq('created') # Default status
        expect(message.content_attributes[:external_error]).to be_nil
      end
    end

    context 'when anti-spam is enabled' do
      before do
        inbox.update(anti_spam_config: { active: true, max_messages: 2, time_window: 1 })
        # Limpa o histórico do mock redis se necessário (MockRedis já inicia limpo a cada teste/yield se for nova instância)
      end

      # MockRedis não persiste estado entre chamadas se eu criar um `MockRedis.new` a cada yield no código.
      # O código usa `$alfred.with { |redis| ... }`.
      # Se eu mockar `and_yield(MockRedis.new)`, cada chamada terá um redis vazio.
      # Preciso usar O MESMO mock instance.
      let(:mock_redis) { MockRedis.new }
      before do
        allow($alfred).to receive(:with).and_yield(mock_redis)
      end

      it 'blocks message when limit is exceeded with identical content' do
        # 1st message (SimilCount 0)
        described_class.new(user, conversation, ActionController::Parameters.new({ content: 'spam' })).perform
        # 2nd message (SimilCount 1 => OK)
        described_class.new(user, conversation, ActionController::Parameters.new({ content: 'spam' })).perform
        
        # 3rd message -> Should Block
        message = described_class.new(user, conversation, ActionController::Parameters.new({ content: 'spam' })).perform
        expect(message.status).to eq('failed') # Status is string
        expect(message.content_attributes[:external_error]).to be_present
      end

      it 'blocks message with similar content (Token Similarity)' do
        msg1 = 'Promoção imperdível de natal'
        msg2 = 'Venha ver a Promoção imperdível de natal!!!'
        
        # 1st
        described_class.new(user, conversation, ActionController::Parameters.new({ content: msg1 })).perform
        # 2nd (Similar)
        described_class.new(user, conversation, ActionController::Parameters.new({ content: msg2 })).perform
        # 3rd (Similar -> Block)
        message = described_class.new(user, conversation, ActionController::Parameters.new({ content: msg1 })).perform
        
        expect(message.status).to eq('failed')
      end

      it 'blocks message with similar content (Levenshtein/Short)' do
        # 1st
        described_class.new(user, conversation, ActionController::Parameters.new({ content: 'teste' })).perform
        # 2nd (testes -> similar 0.83)
        described_class.new(user, conversation, ActionController::Parameters.new({ content: 'testes' })).perform
        # 3rd (testess -> similar to testes 0.85) -> Block
        message = described_class.new(user, conversation, ActionController::Parameters.new({ content: 'testess' })).perform
        
        expect(message.status).to eq('failed')
      end

      it 'does not block different messages' do
        described_class.new(user, conversation, ActionController::Parameters.new({ content: 'oi' })).perform
        described_class.new(user, conversation, ActionController::Parameters.new({ content: 'tudo bem?' })).perform
        message = described_class.new(user, conversation, ActionController::Parameters.new({ content: 'tchau' })).perform
        
        expect(message.status).to_not eq('failed')
      end
      
      it 'ignores case and accents' do
        # 1st
        described_class.new(user, conversation, ActionController::Parameters.new({ content: 'Olá' })).perform
        # 2nd
        described_class.new(user, conversation, ActionController::Parameters.new({ content: 'ola' })).perform
        # 3rd -> Block
        message = described_class.new(user, conversation, ActionController::Parameters.new({ content: 'OLA' })).perform
        
        expect(message.status).to eq('failed')
      end
      
    end
  end
end
