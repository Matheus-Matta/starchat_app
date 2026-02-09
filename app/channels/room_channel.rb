class RoomChannel < ApplicationCable::Channel
  def subscribed
    # TODO: should we only do ensure stream  if current account is present?
    # for now going ahead with guard clauses in update_subscription and broadcast_presence
    Rails.logger.info "[PRESENCE_DEBUG] RoomChannel#subscribed user_id:#{current_user&.id} account_id:#{current_account&.id}"
    current_user
    current_account
    ensure_stream
    update_subscription
    
    if @current_user.is_a?(User)
      # Sync Redis status with DB status on connection to ensure consistency.
      # This respects manual 'offline'/'busy' status if set in DB.
      account_user = @current_user.account_users.find_by(account_id: @current_account.id)
      if account_user&.availability.present?
        db_status = account_user.availability
        ::OnlineStatusTracker.set_status(@current_account.id, @current_user.id, db_status)
        Rails.logger.info "[PRESENCE_DEBUG] Synced user status from DB on connect. DB: #{db_status} (Redis Updated)"
      end
    end

    broadcast_presence
  end

  def update_presence
    Rails.logger.info "[PRESENCE_DEBUG] RoomChannel#update_presence user_id:#{current_user&.id} account_id:#{current_account&.id}"
    # Check if user was already online before updating timestamp
    was_online = ::OnlineStatusTracker.get_presence(@current_account.id, @current_user.class.name, @current_user.id)

    update_subscription
    private_broadcast_presence

    # If user was not online (expired), broadcast their return to the account
    PresenceBroadcastJob.perform_later(@current_account.id) unless was_online
  end

  def unsubscribed
    Rails.logger.info "[PRESENCE_DEBUG] RoomChannel#unsubscribed user_id:#{current_user&.id} account_id:#{current_account&.id}"
    # We are not clearing presence immediately to avoid flickering on reconnect
    # The presence will naturally expire after PRESENCE_DURATION (60s)
    return if @current_account.blank?

    PresenceBroadcastJob.set(wait: ::OnlineStatusTracker::PRESENCE_DURATION).perform_later(@current_account.id)
  end

  private

  def broadcast_presence
    return if @current_account.blank?

    # Full broadcast to everyone in the account
    PresenceBroadcastJob.perform_later(@current_account.id)
    # Also send immediately to the subscriber
    private_broadcast_presence
  end

  def private_broadcast_presence
    return if @current_account.blank?

    data = { account_id: @current_account.id, users: ::OnlineStatusTracker.get_available_users(@current_account.id) }
    data[:contacts] = ::OnlineStatusTracker.get_available_contacts(@current_account.id) if @current_user.is_a? User

    ActionCable.server.broadcast(pubsub_token, { event: 'presence.update', data: data })
  end

  def ensure_stream
    stream_from pubsub_token
    stream_from "account_#{@current_account.id}" if @current_account.present? && @current_user.is_a?(User)
  end

  def update_subscription
    return if @current_account.blank?

    ::OnlineStatusTracker.update_presence(@current_account.id, @current_user.class.name, @current_user.id)
  end

  def pubsub_token
    @pubsub_token ||= params[:pubsub_token]
  end

  def current_user
    @current_user ||= if params[:user_id].blank?
                        ContactInbox.find_by!(pubsub_token: pubsub_token).contact
                      else
                        User.find_by!(pubsub_token: pubsub_token, id: params[:user_id])
                      end
  end

  def current_account
    return if current_user.blank?

    @current_account ||= if @current_user.is_a? Contact
                           @current_user.account
                         else
                           @current_user.accounts.find(params[:account_id])
                         end
  end
end
