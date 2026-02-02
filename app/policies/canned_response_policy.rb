class CannedResponsePolicy < ApplicationPolicy
  def index?
    true
  end

  def create?
    @account_user.permission?(:create_canned_response)
  end

  def update?
    @account_user.permission?(:create_canned_response)
  end

  def destroy?
    @account_user.permission?(:create_canned_response)
  end
end
