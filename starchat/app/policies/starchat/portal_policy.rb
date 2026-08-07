module Starchat::PortalPolicy
  def update?
    @account_user&.permission?('knowledge_base_manage') || super
  end

  def edit?
    @account_user&.permission?('knowledge_base_manage') || super
  end

  def logo?
    @account_user&.permission?('knowledge_base_manage') || super
  end
end
