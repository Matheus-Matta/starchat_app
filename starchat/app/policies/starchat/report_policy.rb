module Starchat::ReportPolicy
  def view?
    @account_user.custom_role&.permissions&.include?('report_manage') || super
  end
end
