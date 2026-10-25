module Events
  # A user's upvote on an event. +previous_direction+ is the direction the vote
  # replaced when the user switched, or +nil+ for a first vote.
  class EventUpvoted < Fact
    SCHEMA = { event_id: Integer, user_id: String, previous_direction: [ String ] }.freeze

    def stream_names
      [ "Event$#{payload.fetch(:event_id)}", VOTES_STREAM ]
    end
  end
end
