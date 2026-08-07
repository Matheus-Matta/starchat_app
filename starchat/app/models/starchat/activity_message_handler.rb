module Starchat::ActivityMessageHandler
  def automation_status_change_activity_content
    if Current.executed_by.instance_of?(Cosmos::Assistant)
      locale = Current.executed_by.account.locale
      if resolved?
        I18n.t(
          'conversations.activity.cosmos.resolved',
          user_name: Current.executed_by.name,
          locale: locale
        )
      elsif open?
        I18n.t(
          'conversations.activity.cosmos.open',
          user_name: Current.executed_by.name,
          locale: locale
        )
      end
    else
      super
    end
  end
end
