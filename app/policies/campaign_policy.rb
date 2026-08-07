class CampaignPolicy < ApplicationPolicy
  def index?
    @account_user.administrator?
  end

  def update?
    @account_user.administrator?
  end

  def show?
    @account_user.administrator?
  end

  def create?
    @account_user.administrator?
  end

  def destroy?
    @account_user.administrator?
  end

  def confirm?
    @account_user.administrator?
  end

  def preview_contacts?
    @account_user.administrator?
  end

  def match_contacts?
    @account_user.administrator?
  end
end
