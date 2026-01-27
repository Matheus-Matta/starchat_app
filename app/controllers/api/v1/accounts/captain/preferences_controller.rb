class Api::V1::Accounts::Cosmos::PreferencesController < Api::V1::Accounts::BaseController
  before_action :current_account
  before_action :authorize_account_update, only: [:update]

  def show
    render json: preferences_payload
  end

  def update
    params_to_update = cosmos_params
    @current_account.cosmos_models = params_to_update[:cosmos_models] if params_to_update[:cosmos_models]
    @current_account.cosmos_features = params_to_update[:cosmos_features] if params_to_update[:cosmos_features]
    @current_account.save!

    render json: preferences_payload
  end

  private

  def preferences_payload
    {
      providers: Llm::Models.providers,
      models: Llm::Models.models,
      features: features_with_account_preferences
    }
  end

  def authorize_account_update
    authorize @current_account, :update?
  end

  def cosmos_params
    permitted = {}
    permitted[:cosmos_models] = merged_cosmos_models if params[:cosmos_models].present?
    permitted[:cosmos_features] = merged_cosmos_features if params[:cosmos_features].present?
    permitted
  end

  def merged_cosmos_models
    existing_models = @current_account.cosmos_models || {}
    existing_models.merge(permitted_cosmos_models)
  end

  def merged_cosmos_features
    existing_features = @current_account.cosmos_features || {}
    existing_features.merge(permitted_cosmos_features)
  end

  def permitted_cosmos_models
    params.require(:cosmos_models).permit(
      :editor, :assistant, :copilot, :label_suggestion,
      :audio_transcription, :help_center_search
    ).to_h.stringify_keys
  end

  def permitted_cosmos_features
    params.require(:cosmos_features).permit(
      :editor, :assistant, :copilot, :label_suggestion,
      :audio_transcription, :help_center_search
    ).to_h.stringify_keys
  end

  def features_with_account_preferences
    preferences = Current.account.cosmos_preferences
    account_features = preferences[:features] || {}
    account_models = preferences[:models] || {}

    Llm::Models.feature_keys.index_with do |feature_key|
      config = Llm::Models.feature_config(feature_key)
      config.merge(
        enabled: account_features[feature_key] == true,
        selected: account_models[feature_key] || config[:default]
      )
    end
  end
end
