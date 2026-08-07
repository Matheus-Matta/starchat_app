module Starchat::ActionCableListener
  include Events::Types

  def user_tokens(account, agents)
    # Get standard tokens from members and admins
    agent_tokens = agents.pluck(:pubsub_token)
    admin_tokens = account.administrators.pluck(:pubsub_token)

    # Get tokens for users with custom roles that have global conversation management permission
    custom_role_tokens = account.account_users.joins(:custom_role)
                                .where("custom_roles.permissions @> ARRAY['conversation_manage']::text[]")
                                .joins(:user).pluck('users.pubsub_token')

    (agent_tokens + admin_tokens + custom_role_tokens).uniq
  end

  def copilot_message_created(event)
    copilot_message = event.data[:copilot_message]
    copilot_thread = copilot_message.copilot_thread
    account = copilot_thread.account
    user = copilot_thread.user

    broadcast(account, [user.pubsub_token], COPILOT_MESSAGE_CREATED, copilot_message.push_event_data)
  end
end
