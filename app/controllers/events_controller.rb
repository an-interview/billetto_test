class EventsController < ApplicationController
  def index
    @events = Event.ordered
    @vote_counts = ReadModels::EventVoteCounts::Count
      .where(event_id: @events.map(&:id))
      .index_by(&:event_id)
  end
end
