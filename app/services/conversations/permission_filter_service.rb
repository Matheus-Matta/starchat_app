class Conversations::PermissionFilterService
  attr_reader :conversations, :user, :account

  def initialize(conversations, user, account)
    @conversations = conversations
    @user = user
    @account = account
  end

  def perform
    return conversations if user_role == 'administrator'

    accessible_conversations
  end

  private

  def accessible_conversations
    inbox_ids = user.inboxes.where(account_id: account.id).select(:id)
    team_ids = account.teams.joins(:team_members).where(team_members: { user_id: user.id }).select(:id)

    scope = conversations.where(inbox_id: inbox_ids).or(conversations.where(team_id: team_ids))

    perms = account_user&.permissions || []

    if perms.include?('conversation_unassigned_manage') || perms.include?('conversation_manage')
      return conversations.where(inbox_id: inbox_ids)
                          .or(conversations.where(team_id: team_ids))
                          .or(conversations.where(assignee_id: nil))
                          .distinct
    end

    scope.distinct
  end

  def account_user
    AccountUser.find_by(account_id: account.id, user_id: user.id)
  end

  def user_role
    account_user&.role
  end
end

Conversations::PermissionFilterService.prepend_mod_with('Conversations::PermissionFilterService')
