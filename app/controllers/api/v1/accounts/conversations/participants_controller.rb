class Api::V1::Accounts::Conversations::ParticipantsController < Api::V1::Accounts::Conversations::BaseController
  include Events::Types

  before_action :validate_participant_ids, only: [:create, :update]

  def show
    @participants = @conversation.conversation_participants
  end

  def create
    participant_ids_to_add = participants_to_be_added_ids

    ActiveRecord::Base.transaction do
      @participants = participant_ids_to_add.map { |user_id| @conversation.conversation_participants.find_or_create_by!(user_id: user_id) }
    end
    @participants.each do |participant|
      Rails.configuration.dispatcher.dispatch(
        Events::Types::CONVERSATION_PARTICIPANT_ADDED,
        Time.zone.now,
        conversation: @conversation,
        user: participant.user
      )
    end
    notify_unread_count_change if participant_ids_to_add.any?
  end

  def update
    participant_ids_to_add = participants_to_be_added_ids
    participant_ids_to_remove = participants_to_be_removed_ids
    # Look the users up before the transaction; after it the removed rows are gone.
    removed_users = User.where(id: participant_ids_to_remove).index_by(&:id)
    added_users = User.where(id: participant_ids_to_add).index_by(&:id)

    ActiveRecord::Base.transaction do
      participant_ids_to_add.each { |user_id| @conversation.conversation_participants.find_or_create_by!(user_id: user_id) }
      participant_ids_to_remove.each { |user_id| @conversation.conversation_participants.find_by(user_id: user_id)&.destroy }
    end

    dispatch_participant_events(CONVERSATION_PARTICIPANT_ADDED, participant_ids_to_add, added_users)
    dispatch_participant_events(CONVERSATION_PARTICIPANT_REMOVED, participant_ids_to_remove, removed_users)

    notify_unread_count_change if (participant_ids_to_add + participant_ids_to_remove).any?
    @participants = @conversation.conversation_participants.reload
    render action: 'show'
  end

  def destroy
    participants_to_remove = @conversation.conversation_participants
                                          .where(user_id: params[:user_ids])
                                          .includes(:user)
                                          .to_a
    participant_ids_to_remove = current_participant_ids & params[:user_ids]

    ActiveRecord::Base.transaction do
      participants_to_remove.each(&:destroy)
    end
    participants_to_remove.each do |participant|
      Rails.configuration.dispatcher.dispatch(
        Events::Types::CONVERSATION_PARTICIPANT_REMOVED,
        Time.zone.now,
        conversation: @conversation,
        user: participant.user
      )
    end
    notify_unread_count_change if participant_ids_to_remove.any?
    head :ok
  end

  private

  def participants_to_be_added_ids
    participant_ids - current_participant_ids
  end

  def participants_to_be_removed_ids
    current_participant_ids - participant_ids
  end

  def current_participant_ids
    @current_participant_ids ||= @conversation.conversation_participants.pluck(:user_id)
  end

  def participant_ids
    @participant_ids ||= params[:user_ids].map(&:to_i)
  end

  def validate_participant_ids
    invalid_ids = participants_to_be_added_ids - @conversation.inbox.assignable_agents.map(&:id)
    return if invalid_ids.empty?

    render json: { error: 'Invalid participant IDs' }, status: :unprocessable_entity
  end

  def dispatch_participant_events(event_name, user_ids, users_by_id)
    user_ids.each do |user_id|
      user = users_by_id[user_id]
      next if user.blank?

      Rails.configuration.dispatcher.dispatch(event_name, Time.zone.now, conversation: @conversation, user: user)
    end
  end

  def notify_unread_count_change
    return unless Current.account.feature_enabled?('conversation_unread_counts')
    return unless Current.account.feature_enabled?('unread_count_for_filters')

    Rails.configuration.dispatcher.dispatch(CONVERSATION_UNREAD_COUNT_CHANGED, Time.zone.now, conversation: @conversation)
  end
end
