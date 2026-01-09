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
    # conversation_manage > conversation_team_manage > conversation_unassigned_manage > conversation_participating_manage
    if permissions.include?('conversation_manage')
      accessible_conversations
    elsif permissions.include?('conversation_team_manage')
      filter_team_and_mine
    elsif permissions.include?('conversation_unassigned_manage')
      filter_unassigned_and_mine
    elsif permissions.include?('conversation_participating_manage')
      accessible_conversations.assigned_to(user)
    else
      Conversation.none
    end
  end

  def filter_team_and_mine
    mine = accessible_conversations.assigned_to(user)
    team = accessible_conversations.where(team_id: user.team_ids)
    
    queries = [mine, team]
    
    if permissions.include?('conversation_unassigned_manage')
      # Explicitly fetch global unassigned to ensure they are included
      # bypassing any implicit filters in accessible_conversations that might restrict to team
      unassigned = Conversation.where(assignee_id: nil)
                               .where(account_id: account.id)
                               # Ensure we don't fetch unassigned from Inboxes we don't have access to,
                               # UNLESS unassigned_manage implies global access.
                               # Assuming safe global access for unassigned based on previous context.
                               
      queries << unassigned
    end

    union_query = queries.map(&:to_sql).join(" UNION ")
    Conversation.from("(#{union_query}) as conversations").where(account_id: account.id)
  end

  def filter_unassigned_and_mine
    inbox_ids = user.inboxes.where(account_id: account.id).select(:id)
    team_ids = account.teams.joins(:team_members).where(team_members: { user_id: user.id }).select(:id)

    Conversation.where(inbox_id: inbox_ids)
                .or(Conversation.where(team_id: team_ids))
                .or(Conversation.where(assignee_id: nil))
                .distinct
                .where(account_id: account.id)
  end
end
