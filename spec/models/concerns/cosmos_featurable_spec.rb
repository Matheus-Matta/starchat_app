# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CosmosFeaturable do
  let(:account) { create(:account) }

  describe 'dynamic method generation' do
    it 'generates enabled? methods for all features' do
      Llm::Models.feature_keys.each do |feature_key|
        expect(account).to respond_to("cosmos_#{feature_key}_enabled?")
      end
    end

    it 'generates model accessor methods for all features' do
      Llm::Models.feature_keys.each do |feature_key|
        expect(account).to respond_to("cosmos_#{feature_key}_model")
      end
    end
  end

  describe 'feature enabled methods' do
    context 'when no features are explicitly enabled' do
      it 'returns false for all features' do
        Llm::Models.feature_keys.each do |feature_key|
          expect(account.send("cosmos_#{feature_key}_enabled?")).to be false
        end
      end
    end

    context 'when features are explicitly enabled' do
      before do
        account.update!(cosmos_features: { 'editor' => true, 'assistant' => true })
      end

      it 'returns true for enabled features' do
        expect(account.cosmos_editor_enabled?).to be true
        expect(account.cosmos_assistant_enabled?).to be true
      end

      it 'returns false for disabled features' do
        expect(account.cosmos_copilot_enabled?).to be false
        expect(account.cosmos_label_suggestion_enabled?).to be false
      end
    end

    context 'when cosmos_features is nil' do
      before do
        account.update!(cosmos_features: nil)
      end

      it 'returns false for all features' do
        Llm::Models.feature_keys.each do |feature_key|
          expect(account.send("cosmos_#{feature_key}_enabled?")).to be false
        end
      end
    end
  end

  describe 'model accessor methods' do
    context 'when no models are explicitly configured' do
      it 'returns default models for all features' do
        Llm::Models.feature_keys.each do |feature_key|
          expected_default = Llm::Models.default_model_for(feature_key)
          expect(account.send("cosmos_#{feature_key}_model")).to eq(expected_default)
        end
      end
    end

    context 'when models are explicitly configured' do
      before do
        account.update!(cosmos_models: {
                          'editor' => 'gpt-4.1-mini',
                          'assistant' => 'gpt-5.1',
                          'label_suggestion' => 'gpt-4.1-nano'
                        })
      end

      it 'returns configured models for configured features' do
        expect(account.cosmos_editor_model).to eq('gpt-4.1-mini')
        expect(account.cosmos_assistant_model).to eq('gpt-5.1')
        expect(account.cosmos_label_suggestion_model).to eq('gpt-4.1-nano')
      end

      it 'returns default models for unconfigured features' do
        expect(account.cosmos_copilot_model).to eq(Llm::Models.default_model_for('copilot'))
        expect(account.cosmos_audio_transcription_model).to eq(Llm::Models.default_model_for('audio_transcription'))
      end
    end

    context 'when configured with invalid model' do
      before do
        account.cosmos_models = { 'editor' => 'invalid-model' }
      end

      it 'falls back to default model' do
        expect(account.cosmos_editor_model).to eq(Llm::Models.default_model_for('editor'))
      end
    end

    context 'when cosmos_models is nil' do
      before do
        account.update!(cosmos_models: nil)
      end

      it 'returns default models for all features' do
        Llm::Models.feature_keys.each do |feature_key|
          expected_default = Llm::Models.default_model_for(feature_key)
          expect(account.send("cosmos_#{feature_key}_model")).to eq(expected_default)
        end
      end
    end
  end

  describe 'integration with existing cosmos_preferences' do
    it 'enabled? methods use the same logic as cosmos_preferences[:features]' do
      account.update!(cosmos_features: { 'editor' => true, 'copilot' => true })
      prefs = account.cosmos_preferences

      Llm::Models.feature_keys.each do |feature_key|
        expect(account.send("cosmos_#{feature_key}_enabled?")).to eq(prefs[:features][feature_key])
      end
    end

    it 'model methods use the same logic as cosmos_preferences[:models]' do
      account.update!(cosmos_models: { 'editor' => 'gpt-4.1-mini', 'assistant' => 'gpt-5.2' })
      prefs = account.cosmos_preferences

      Llm::Models.feature_keys.each do |feature_key|
        expect(account.send("cosmos_#{feature_key}_model")).to eq(prefs[:models][feature_key])
      end
    end
  end
end
