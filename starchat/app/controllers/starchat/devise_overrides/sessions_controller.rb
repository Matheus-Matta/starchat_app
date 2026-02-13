module Starchat::DeviseOverrides::SessionsController
  include SamlAuthenticationHelper

  QUEUE_LOG_LIMIT = 50
  LOGOUT_CONVERSATION_LIMIT = 200
  LOGOUT_CONVERSATION_STATUSES = %w[open pending snoozed].freeze

  def create
    if saml_user_attempting_password_auth?(params[:email], sso_auth_token: params[:sso_auth_token])
      render json: {
        success: false,
        message: I18n.t('messages.login_saml_user'),
        errors: [I18n.t('messages.login_saml_user')]
      }, status: :unauthorized
      return
    end

    super
  end

  def render_create_success
    create_audit_event('sign_in')
    super
  end

  def destroy
    create_audit_event('sign_out')
    log_assigned_conversations_on_logout
    super
  end

  def create_audit_event(action)
    return unless @resource

    associated_type = 'Account'
    @resource.accounts.each do |account|
      @resource.audits.create(
        action: action,
        user_id: @resource.id,
        associated_id: account.id,
        associated_type: associated_type
      )
    end
  end

  def log_assigned_conversations_on_logout
    return unless @resource

    @resource.accounts.find_each do |account|
      conversations = account.conversations
                             .where(assignee_id: @resource.id, status: LOGOUT_CONVERSATION_STATUSES)
                             .limit(LOGOUT_CONVERSATION_LIMIT)
      next if conversations.blank?

      queue_cache = {}

      conversations.find_each do |conversation|
        queue_cache[conversation.inbox_id] ||= ::AutoAssignment::InboxRoundRobinService
                                              .new(inbox: conversation.inbox)
                                              .queue_snapshot(limit: QUEUE_LOG_LIMIT)

        Starchat::AuditLog.create(
          auditable: conversation,
          action: 'assignee_sign_out',
          user: @resource,
          associated: account,
          audited_changes: {
            assignee_id: conversation.assignee_id,
            inbox_id: conversation.inbox_id,
            conversation_display_id: conversation.display_id,
            conversation_status: conversation.status,
            assignment_source: 'sign_out',
            queue_snapshot: queue_cache[conversation.inbox_id],
            queue_size: queue_cache[conversation.inbox_id]&.size
          }.compact
        )
      end
    end
  rescue StandardError => e
    Rails.logger.error("Logout audit log failed for user #{@resource&.id}: #{e.class} #{e.message}")
  end
end
