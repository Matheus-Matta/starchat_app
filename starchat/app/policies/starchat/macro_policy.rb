# CustomRole defines a `create_macro` permission, but the core policy lets any
# account user create and edit macros, so a custom role that was never granted it
# still got through. This gates the write actions on that permission.
#
# Only users who actually carry a custom role are affected: administrators and
# plain agents have none, so they fall through to the core rules unchanged.
module Starchat::MacroPolicy
  def create?
    macro_permission? && super
  end

  def update?
    macro_permission? && super
  end

  def destroy?
    macro_permission? && super
  end

  private

  def macro_permission?
    return true if @account_user.custom_role.blank?

    @account_user.custom_role.permissions.include?('create_macro')
  end
end
