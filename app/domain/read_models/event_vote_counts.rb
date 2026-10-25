module ReadModels
  # Synchronous projection of the active vote per user and event.
  #
  # The projection maintains two tables:
  #
  # - +event_vote_states+ stores at most one row per +[event_id, user_id]+,
  #   with the current +"up"+ or +"down"+ direction;
  # - +event_vote_counts+ stores per-event up/down tallies derived from the
  #   state changes.
  #
  # The unique index on +event_vote_states+ enforces the one-active-vote rule at
  # the database level. The projection runs inside the publishing command's
  # transaction, so the state and tally are visible as soon as the command
  # commits. Applying a fact twice is harmless: the previous and next direction
  # are equal, so no tally change is recorded.
  class EventVoteCounts
    include Handler
    subscribes_to Events::EventUpvoted, Events::EventDownvoted, Events::EventVoteWithdrawn

    # The one-active-vote projection row for an event and user.
    class State < ApplicationRecord
      self.table_name = "event_vote_states"

      belongs_to :event

      validates :direction, inclusion: { in: %w[up down] }
    end

    # The up/down tally for an event.
    class Count < ApplicationRecord
      self.table_name = "event_vote_counts"

      belongs_to :event
    end

    def call(fact)
      ApplicationRecord.transaction do
        next unless claim(fact.event_id)

        apply(fact)
      end
    end

    private

    # Records the fact as processed. Returns false when it was already applied.
    def claim(event_id)
      now = Time.current
      inserted = ProcessedEvent.insert_all(
        [ { handler: self.class.name, event_id: event_id, created_at: now, updated_at: now } ],
        unique_by: [ :handler, :event_id ],
        returning: [ :id ]
      )

      inserted.rows.any?
    end

    # Moves the state and tally from the previous direction to the fact's
    # direction. Withdrawals have no direction, so they remove the state row
    # and subtract the previous direction from the tally.
    def apply(fact)
      event_id = fact.payload.fetch(:event_id)
      user_id = fact.payload.fetch(:user_id)
      previous = State.find_by(event_id: event_id, user_id: user_id)&.direction
      current = Events::VoteDirection.for_fact(fact)
      return if previous == current

      store_state(event_id, user_id, current)
      adjust_count(event_id, previous: previous, current: current)
    end

    def store_state(event_id, user_id, direction)
      if direction
        now = Time.current
        State.upsert_all(
          [ { event_id: event_id, user_id: user_id, direction: direction, created_at: now, updated_at: now } ],
          unique_by: [ :event_id, :user_id ],
          on_duplicate: Arel.sql("direction = excluded.direction, updated_at = excluded.updated_at")
        )
      else
        State.where(event_id: event_id, user_id: user_id).delete_all
      end
    end

    def adjust_count(event_id, previous:, current:)
      up = current == "up" ? 1 : 0
      down = current == "down" ? 1 : 0
      up -= 1 if previous == "up"
      down -= 1 if previous == "down"

      now = Time.current
      Count.upsert_all(
        [ { event_id: event_id, upvotes: up, downvotes: down, created_at: now, updated_at: now } ],
        unique_by: [ :event_id ],
        on_duplicate: Arel.sql(
          "upvotes = event_vote_counts.upvotes + excluded.upvotes, " \
          "downvotes = event_vote_counts.downvotes + excluded.downvotes, " \
          "updated_at = excluded.updated_at"
        )
      )
    end
  end
end
