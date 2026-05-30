module Starchat::Account
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

  def saml_enabled?
    saml_settings&.saml_enabled? || false
  end

  private

  def sync_assignment_features
    if feature_enabled?('assignment_v2')
      send('feature_advanced_assignment=', true)
    else
      # Disable advanced_assignment when assignment_v2 is disabled
      send('feature_advanced_assignment=', false)
    end
  end
end
