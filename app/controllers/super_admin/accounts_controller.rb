class SuperAdmin::AccountsController < SuperAdmin::ApplicationController
  def resource_params
    permitted_params = super
    permitted_params[:limits] = permitted_params[:limits].to_h.compact

    if params[:enabled_features].present?
      checked = params[:enabled_features].select { |_k, v| v == 'true' }.keys.map(&:to_sym)

      form_keys = params[:enabled_features].keys.to_set
      preserved = requested_resource.enabled_features.keys
                                    .map { |name| :"feature_#{name}" }
                                    .reject { |flag| form_keys.include?(flag.to_s) }

      permitted_params[:selected_feature_flags] = checked + preserved
    end

    permitted_params
  end

  def seed
    Internal::SeedAccountJob.perform_later(requested_resource)
    # rubocop:disable Rails/I18nLocaleTexts
    redirect_back(fallback_location: [namespace, requested_resource], notice: 'Account seeding triggered')
    # rubocop:enable Rails/I18nLocaleTexts
  end

  def reset_cache
    requested_resource.reset_cache_keys
    # rubocop:disable Rails/I18nLocaleTexts
    redirect_back(fallback_location: [namespace, requested_resource], notice: 'Cache keys cleared')
    # rubocop:enable Rails/I18nLocaleTexts
  end

  def destroy
    account = Account.find(params[:id])

    DeleteObjectJob.perform_later(account) if account.present?
    # rubocop:disable Rails/I18nLocaleTexts
    redirect_back(fallback_location: [namespace, requested_resource], notice: 'Account deletion is in progress.')
    # rubocop:enable Rails/I18nLocaleTexts
  end
end

SuperAdmin::AccountsController.prepend_mod_with('SuperAdmin::AccountsController')
