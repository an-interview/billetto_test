module ReadModels
  # Keeps per-event up/down vote tallies, built from EventUpvoted /
  # EventDownvoted facts.
  #
  # Each fact carries the direction it replaced (nil for a user's first vote),
  # so the tally is adjusted by a delta: a first vote adds one, and a switch
  # moves one from the old column to the new one. Deltas depend only on the
  # fact's own previous/next directions, so applying facts in any order yields
  # the same tally.
  #
  # Applying is idempotent: each fact is claimed in `processed_events`, so a
  # retried or replayed job does not double count. The counter update is a single
  # atomic upsert, so concurrent first votes for the same event cannot race on
  # row creation.
  class EventVoteCounts
    include Handler.async(queue: "low")
    subscribes_to Events::EventUpvoted, Events::EventDownvoted

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

    def apply(fact)
      direction = direction_for(fact)
      previous = fact.payload[:previous_direction]
      return if previous == direction

      up = direction == "up" ? 1 : 0
      down = direction == "down" ? 1 : 0
      up -= 1 if previous == "up"
      down -= 1 if previous == "down"

      adjust(fact.payload.fetch(:event_id), up: up, down: down)
    end

    def direction_for(fact)
      fact.event_type == Events::EventUpvoted.name ? "up" : "down"
    end

    def adjust(event_id, up:, down:)
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
