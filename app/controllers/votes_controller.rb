class VotesController < ApplicationController
  before_action :require_authentication!

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
