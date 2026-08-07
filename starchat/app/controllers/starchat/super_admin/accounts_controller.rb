module Starchat::SuperAdmin::AccountsController
  def create
    manually_managed_features = extract_manually_managed_features

    super do |account|
      update_manually_managed_features(account, manually_managed_features)
    end
  end

  def update
    manually_managed_features = extract_manually_managed_features
    update_manually_managed_features(requested_resource, manually_managed_features)

    super
  end

  private

  def extract_manually_managed_features
    return unless params[:account] && params[:account][:manually_managed_features].present?

    params[:account].delete(:manually_managed_features)
  end

  def update_manually_managed_features(account, features)
    return if features.blank?

    service = ::Internal::Accounts::InternalAttributesService.new(account)
    service.manually_managed_features = features
  end
end
