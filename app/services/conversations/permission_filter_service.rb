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

    scope = conversations.where(inbox_id: inbox_ids)
                         .or(conversations.where(team_id: team_ids))
                         .or(conversations.where(assignee_id: user.id))

    perms = account_user&.permissions || []

    if perms.include?('conversation_unassigned_manage') || perms.include?('conversation_manage')
      # Unassigned conversations are still scoped to accessible inboxes/teams.
      scope = scope.or(
        conversations.where(inbox_id: inbox_ids, assignee_id: nil)
      ).or(
        conversations.where(team_id: team_ids, assignee_id: nil)
      )
    end

    deduplicate(scope)
  end

  # Deduplicating with an id subquery rather than DISTINCT: Postgres rejects
  # SELECT DISTINCT when ORDER BY references an expression that is not in the select
  # list, which is exactly what sorting by unread count does (it orders by a
  # correlated COUNT subquery). DISTINCT here made `sort_by: 'unread'` raise
  # PG::InvalidColumnReference.
  def deduplicate(scope)
    conversations.where(id: scope.select(:id))
  end

  def account_user
    AccountUser.find_by(account_id: account.id, user_id: user.id)
  end

  def user_role
    account_user&.role
  end
end

Conversations::PermissionFilterService.prepend_mod_with('Conversations::PermissionFilterService')
