class ProtocolPolicyPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def create?
    @user.administrator?
  end

  def update?
    @user.administrator?
  end

  def destroy?
    @user.administrator?
  end
end
