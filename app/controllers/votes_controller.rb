class VotesController < ApplicationController
  before_action :require_authentication!

  # A bad direction (or any other invalid attribute) is a user error, not a
  # crash: send the voter back to the listing with a friendly message.
  rescue_from Command::ValidationError do
    redirect_to events_path, alert: "That vote isn't valid."
  end

  # Records the signed-in user's upvote or downvote. Repeating the active
  # direction is a no-op; the opposite direction switches the active vote.
  def create
    Rails.configuration.command_bus.call(
      Events::CastVote.new(
        tid: event.tid,
        user_id: current_user.id,
        direction: params[:direction]
      )
    )

    redirect_to events_path, notice: "Vote recorded"
  end

  # Removes the signed-in user's active vote. Withdrawing without an active vote
  # is a no-op.
  def destroy
    Rails.configuration.command_bus.call(
      Events::WithdrawVote.new(
        tid: event.tid,
        user_id: current_user.id
      )
    )

    redirect_to events_path, notice: "Vote withdrawn"
  end

  private

  def event
    @event ||= Event.find(params[:event_id])
  end
end
