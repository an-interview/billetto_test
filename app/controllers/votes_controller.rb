class VotesController < ApplicationController
  before_action :require_authentication!

  # A bad direction (or any other invalid attribute) is a user error, not a
  # crash: send the voter back to the listing with a friendly message.
  rescue_from Command::ValidationError do
    redirect_to events_path, alert: "That vote isn't valid."
  end

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

  private

  def event
    @event ||= Event.find(params[:event_id])
  end
end
