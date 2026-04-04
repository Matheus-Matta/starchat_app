class Api::V1::Accounts::Conversations::ParticipantsController < Api::V1::Accounts::Conversations::BaseController
  def show
    @participants = @conversation.conversation_participants
  end

  def create
    ActiveRecord::Base.transaction do
      @participants = participants_to_be_added_ids.map { |user_id| @conversation.conversation_participants.find_or_create_by(user_id: user_id) }
    end
    @participants.each do |participant|
      Rails.configuration.dispatcher.dispatch(
        Events::Types::CONVERSATION_PARTICIPANT_ADDED,
        Time.zone.now,
        conversation: @conversation,
        user: participant.user
      )
    end
  end

  def update
    added_ids   = participants_to_be_added_ids
    removed_ids = participants_to_be_removed_ids
    removed_users = User.where(id: removed_ids).index_by(&:id)
    ActiveRecord::Base.transaction do
      added_ids.each   { |user_id| @conversation.conversation_participants.find_or_create_by(user_id: user_id) }
      removed_ids.each { |user_id| @conversation.conversation_participants.find_by(user_id: user_id)&.destroy }
    end
    added_ids.each do |user_id|
      user = User.find_by(id: user_id)
      next unless user

      Rails.configuration.dispatcher.dispatch(
        Events::Types::CONVERSATION_PARTICIPANT_ADDED,
        Time.zone.now,
        conversation: @conversation,
        user: user
      )
    end
    removed_ids.each do |user_id|
      user = removed_users[user_id]
      next unless user

      Rails.configuration.dispatcher.dispatch(
        Events::Types::CONVERSATION_PARTICIPANT_REMOVED,
        Time.zone.now,
        conversation: @conversation,
        user: user
      )
    end
    @participants = @conversation.conversation_participants
    render action: 'show'
  end

  def destroy
    participants_to_remove = @conversation.conversation_participants
                                          .where(user_id: params[:user_ids])
                                          .includes(:user)
                                          .to_a
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
    head :ok
  end

  private

  def participants_to_be_added_ids
    params[:user_ids] - current_participant_ids
  end

  def participants_to_be_removed_ids
    current_participant_ids - params[:user_ids]
  end

  def current_participant_ids
    @current_participant_ids ||= @conversation.conversation_participants.pluck(:user_id)
  end
end
