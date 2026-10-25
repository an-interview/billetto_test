class EventsController < ApplicationController
  # Renders the event listing with vote tallies and, for signed-in users, each
  # event's current vote so the view can highlight it and offer withdrawal.
  def index
    @events = Event.ordered
    @vote_counts = ReadModels::EventVoteCounts::Count
      .where(event_id: @events.map(&:id))
      .index_by(&:event_id)
    @user_votes = current_user_votes
  end

  private

  # Returns a hash of event id to +"up"+, +"down"+, or +nil+ for the signed-in
  # user, or an empty hash for anonymous visitors.
  def current_user_votes
    return {} unless authenticated?

    @events.each_with_object({}) do |event, votes|
      votes[event.id] = Events::VoteHistory.current_direction(
        event_id: event.id,
        user_id: current_user.id
      )
    end
  end
end
