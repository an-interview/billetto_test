module Events
  # Reads a user's active vote from an event's fact stream.
  #
  # The event log is append-only, so the active vote is the latest vote fact for
  # the user. A withdrawal fact clears it. This query is shared by command
  # handling (to enforce one active vote) and the listing (to render the current
  # vote state).
  class VoteHistory
    # call-seq:
    #   VoteHistory.current_direction(event_id: 42, user_id: "user_1") # => "up"
    #   VoteHistory.current_direction(event_id: 42, user_id: "user_1") # => nil
    #
    # Returns +"up"+, +"down"+, or +nil+ when the user has no active vote.
    def self.current_direction(event_id:, user_id:, event_store: Rails.configuration.event_store)
      fact = event_store
        .read
        .stream(stream_name(event_id))
        .to_a
        .reverse
        .find { |candidate| vote_fact?(candidate) && candidate.payload[:user_id].to_s == user_id.to_s }

      direction_for(fact)
    end

    def self.stream_name(event_id)
      "Event$#{event_id}"
    end

    def self.vote_fact?(fact)
      [
        EventUpvoted.name,
        EventDownvoted.name,
        EventVoteWithdrawn.name
      ].include?(fact.event_type)
    end

    def self.direction_for(fact)
      return nil unless fact

      case fact.event_type
      when EventUpvoted.name then "up"
      when EventDownvoted.name then "down"
      end
    end

    private_class_method :stream_name, :vote_fact?, :direction_for
  end
end
