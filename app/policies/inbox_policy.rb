class InboxPolicy < ApplicationPolicy
  class Scope
    attr_reader :user_context, :user, :scope, :account, :account_user

    def initialize(user_context, scope)
      @user_context = user_context
      @user = user_context[:user]
      @account = user_context[:account]
      @account_user = user_context[:account_user]
      @scope = scope
    end

    def resolve
      return scope if @account_user.administrator?

      direct_inbox_ids = user.inbox_members.select(:inbox_id)

      team_ids = account.teams.joins(:team_members).where(team_members: { user_id: user.id }).select(:id)
      team_inbox_ids = Conversation.where(account_id: account.id, team_id: team_ids).select(:inbox_id)

      scope.where(id: direct_inbox_ids).or(scope.where(id: team_inbox_ids)).distinct
    end
  end

  def index?
    true
  end

  def show?
    # FIXME: for agent bots, lets bring this validation to policies as well in future
    return true if @user.is_a?(AgentBot)

    Current.user.assigned_inboxes.include? record
  end

  def assignable_agents?
    true
  end

  def agent_bot?
    true
  end

  def campaigns?
    @account_user.administrator?
  end

  def create?
    @account_user.administrator?
  end

  def update?
    @account_user.administrator?
  end

  def destroy?
    @account_user.administrator?
  end

  def set_agent_bot?
    @account_user.administrator?
  end

  def avatar?
    @account_user.administrator?
  end

  def sync_templates?
    @account_user.administrator?
  end

  def health?
    @account_user.administrator?
  end
end
