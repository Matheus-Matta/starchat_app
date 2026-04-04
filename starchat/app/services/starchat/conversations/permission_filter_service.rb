module Starchat::Conversations::PermissionFilterService
  def perform
    return filter_by_permissions(permissions) if user_has_custom_role?

    super
  end

  private

  def user_has_custom_role?
    user_role == 'agent' && account_user&.custom_role_id.present?
  end

  def permissions
    account_user&.permissions || []
  end

  def filter_by_permissions(permissions)
    # Permission-based filtering with hierarchy
    # conversation_manage > conversation_team_manage > conversation_unassigned_manage > conversation_participating_manage > conversation_participating_view
    if permissions.include?('conversation_manage')
      accessible_conversations
    elsif permissions.include?('conversation_team_manage')
      filter_team_and_mine
    elsif permissions.include?('conversation_unassigned_manage')
      filter_unassigned_and_mine
    elsif permissions.include?('conversation_participating_manage')
      participating = conversations.joins(:conversation_participants)
                                   .where(conversation_participants: { user_id: user.id })
                                   .where(conversations: { account_id: account.id })
      assigned = conversations.where(assignee_id: user.id)
      participating.or(assigned).distinct
    elsif permissions.include?('conversation_participating_view')
      conversations.joins(:conversation_participants)
                   .where(conversation_participants: { user_id: user.id })
                   .where(conversations: { account_id: account.id })
    else
      Conversation.none
    end
  end

  def filter_team_and_mine
    inbox_ids = user.inboxes.where(account_id: account.id).select(:id)
    team_ids  = account.teams.joins(:team_members).where(team_members: { user_id: user.id }).select(:id)

    scope = Conversation.where(account_id: account.id)

    # Conversations in user's teams (assigned or unassigned)
    team_convs = scope.where(team_id: team_ids)

    # Conversations assigned directly to the user, regardless of inbox/team membership
    mine = scope.where(assignee_id: user.id)

    result = team_convs.or(mine)

    if permissions.include?('conversation_unassigned_manage')
      # Add unassigned conversations scoped to accessible inboxes and teams only
      unassigned_in_inbox = scope.where(assignee_id: nil, inbox_id: inbox_ids)
      unassigned_in_team  = scope.where(assignee_id: nil, team_id: team_ids)
      result = result.or(unassigned_in_inbox).or(unassigned_in_team)
    end

    result.distinct
  end

  def filter_unassigned_and_mine
    inbox_ids = user.inboxes.where(account_id: account.id).select(:id)
    team_ids  = account.teams.joins(:team_members).where(team_members: { user_id: user.id }).select(:id)

    scope = Conversation.where(account_id: account.id)

    # Unassigned conversations are scoped to inboxes and teams the user belongs to
    unassigned_in_inbox = scope.where(assignee_id: nil, inbox_id: inbox_ids)
    unassigned_in_team  = scope.where(assignee_id: nil, team_id: team_ids)

    # Conversations assigned to the user (regardless of inbox/team)
    mine = scope.where(assignee_id: user.id)

    unassigned_in_inbox.or(unassigned_in_team).or(mine).distinct
  end
end
