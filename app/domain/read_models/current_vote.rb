module ReadModels
  # Reads active votes from the +event_vote_states+ projection.
  #
  # This is the read-side source for enforcing one active vote and for rendering
  # the signed-in user's vote on the listing. It does not read the event store.
  class CurrentVote
    # call-seq:
    #   CurrentVote.direction(event_id: 42, user_id: "user_1") # => "up"
    #   CurrentVote.direction(event_id: 42, user_id: "user_1") # => nil
    #
    # Returns +"up"+, +"down"+, or +nil+ when the user has no active vote.
    def self.direction(event_id:, user_id:)
      EventVoteCounts::State.find_by(event_id: event_id, user_id: user_id)&.direction
    end

    # call-seq:
    #   CurrentVote.directions(event_ids: [1, 2], user_id: "user_1")
    #     # => { 1 => "up", 2 => "down" }
    #
    # Returns a hash of event id to direction for events where the user has an
    # active vote. Missing event ids are omitted.
    def self.directions(event_ids:, user_id:)
      EventVoteCounts::State
        .where(event_id: event_ids, user_id: user_id)
        .pluck(:event_id, :direction)
        .to_h
    end
  end
end
