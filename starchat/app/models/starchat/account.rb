module Starchat::Account
  # Transitional marker for the Cosmos V1 to V2 rollout. New cloud accounts get
  # this marker so plan reconciliation can enable V2 for them without upgrading
  # existing paid accounts. Remove once every account is migrated to V2.
  COSMOS_V2_DEFAULT_ELIGIBLE = 'cosmos_v2_default_eligible'.freeze

  class << self
    # A single interval for every account. This used to be a plan-keyed map, which
    # meant accounts with no plan_name never auto-synced at all.
    def cosmos_document_sync_intervals
      parse_cosmos_document_sync_interval(InstallationConfig.find_by(name: 'COSMOS_DOCUMENT_AUTO_SYNC_INTERVALS')&.value)
    end

    private

    def parse_cosmos_document_sync_interval(configured_interval)
      return nil if configured_interval.blank?

      # Still accepts the old plan-keyed hash so an existing installation config
      # keeps working; any configured value is applied to every account now.
      configured_interval = JSON.parse(configured_interval) if configured_interval.is_a?(String) && configured_interval.strip.start_with?('{')
      configured_interval = configured_interval.values.compact.first if configured_interval.is_a?(Hash)

      interval_hours = Integer(configured_interval, exception: false)
      interval_hours if interval_hours&.positive?
    rescue JSON::ParserError
      nil
    end
  end

  # TODO: Remove this when we upgrade administrate gem to the latest version
  # this is a temporary method since current administrate doesn't support virtual attributes
  def manually_managed_features; end

  # Auto-sync advanced_assignment with assignment_v2 when features are bulk-updated via admin UI
  def selected_feature_flags=(features)
    super
    sync_assignment_features
  end

  def mark_for_deletion(reason = 'manual_deletion')
    result = custom_attributes.merge!(
      'marked_for_deletion_at' => 7.days.from_now.iso8601,
      'marked_for_deletion_reason' => reason
    ) && save

    if result
      mailer = AdministratorNotifications::AccountNotificationMailer.with(account: self)
      mailer.account_deletion(self, reason).deliver_later
    end

    result
  end

  def unmark_for_deletion
    custom_attributes.delete('marked_for_deletion_at') && custom_attributes.delete('marked_for_deletion_reason') && save
  end

  def cosmos_document_sync_interval(sync_interval = Starchat::Account.cosmos_document_sync_intervals)
    return nil unless sync_interval.is_a?(Integer) && sync_interval.positive?

    sync_interval.hours
  end

  def saml_enabled?
    saml_settings&.saml_enabled? || false
  end

  private

  def enable_default_features
    super
    if StarchatsApp.self_hosted_enterprise?
      enable_features('cosmos_integration', 'cosmos_integration_v2')
    elsif StarchatsApp.starchats_cloud?
      internal_attributes[COSMOS_V2_DEFAULT_ELIGIBLE] = true
    end
  end

  def sync_assignment_features
    if feature_enabled?('assignment_v2')
      # Every account is enterprise here, so this is no longer plan-gated.
      send('feature_advanced_assignment=', true)
    else
      # Disable advanced_assignment when assignment_v2 is disabled
      send('feature_advanced_assignment=', false)
    end
  end
end
