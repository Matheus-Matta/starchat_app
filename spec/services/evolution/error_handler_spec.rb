# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Evolution::ErrorHandler do
  describe '.handle_send_error' do
    context 'when phone number not found' do
      it 'returns phone not found error for "phone not exist"' do
        error = StandardError.new('phone not exist')
        result = described_class.handle_send_error(error)

        expect(result[:error_type]).to eq(:phone_not_found)
        expect(result[:user_message]).to include('número pode não existir')
      end

      it 'returns phone not found error for "participant not found"' do
        error = StandardError.new('participant not found')
        result = described_class.handle_send_error(error)

        expect(result[:error_type]).to eq(:phone_not_found)
      end

      it 'returns phone not found error for Portuguese message' do
        error = StandardError.new('numero não existe no WhatsApp')
        result = described_class.handle_send_error(error)

        expect(result[:error_type]).to eq(:phone_not_found)
      end
    end

    context 'when connection error occurs' do
      it 'returns connection error for timeout' do
        error = StandardError.new('Request timeout')
        result = described_class.handle_send_error(error)

        expect(result[:error_type]).to eq(:connection_error)
        expect(result[:user_message]).to include('conexão')
      end

      it 'returns connection error for "connection refused"' do
        error = StandardError.new('Connection refused')
        result = described_class.handle_send_error(error)

        expect(result[:error_type]).to eq(:connection_error)
      end
    end

    context 'when media error occurs' do
      it 'returns media error for "media too large"' do
        error = StandardError.new('Media file too large')
        result = described_class.handle_send_error(error)

        expect(result[:error_type]).to eq(:media_error)
        expect(result[:user_message]).to include('arquivo')
      end

      it 'returns media error for unsupported format' do
        error = StandardError.new('Unsupported media format')
        result = described_class.handle_send_error(error)

        expect(result[:error_type]).to eq(:media_error)
      end
    end

    context 'when generic error occurs' do
      it 'returns generic error type' do
        error = StandardError.new('Random error message')
        result = described_class.handle_send_error(error)

        expect(result[:error_type]).to eq(:generic_error)
        expect(result[:user_message]).to include('Erro ao enviar mensagem')
      end
    end

    context 'when error is a string' do
      it 'handles string errors' do
        result = described_class.handle_send_error('phone not exist')

        expect(result[:error_type]).to eq(:phone_not_found)
        expect(result[:technical_message]).to eq('phone not exist')
      end
    end

    it 'includes technical message for debugging' do
      error = StandardError.new('Detailed error info')
      result = described_class.handle_send_error(error)

      expect(result[:technical_message]).to eq('Detailed error info')
    end
  end
end
