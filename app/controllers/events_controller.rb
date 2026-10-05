class EventsController < ApplicationController
  def index
    @events = Event.ordered
  end
end
