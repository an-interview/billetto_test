module Events
  # A user removed their active vote from an event.
  #
  # The fact records the direction that was active so the vote-count projection
  # can subtract from the correct tally. Withdrawn votes remain in the event log;
  # the active vote is stored in the ReadModels::EventVoteCounts state projection.
  class EventVoteWithdrawn < Fact
    SCHEMA = { event_id: Integer, user_id: String, previous_direction: String }.freeze

    # call-seq:
    #   fact.stream_names # => ["Event$42", "EventVotes"]
    #
    # Publishes to the event's own stream and links into the stream used to
    # rebuild the vote-count read model.
    def stream_names
      [ "Event$#{payload.fetch(:event_id)}", VOTES_STREAM ]
    end
  end
end
