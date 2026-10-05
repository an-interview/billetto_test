module ReadModels
  # Keeps per-event up/down vote tallies, built from EventUpvoted /
  # EventDownvoted facts.
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

        increment(
          fact.payload.fetch(:event_id),
          fact.event_type == "Events::EventUpvoted" ? :upvotes : :downvotes
        )
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

    def increment(event_id, column)
      now = Time.current
      values = { event_id: event_id, upvotes: 0, downvotes: 0, created_at: now, updated_at: now }
      values[column] = 1

      Count.upsert_all(
        [ values ],
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
