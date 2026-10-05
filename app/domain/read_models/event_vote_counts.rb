module ReadModels
  # Keeps per-event up/down vote tallies, built from EventUpvoted /
  # EventDownvoted facts.
  class EventVoteCounts
    include Handler.async(queue: "low")
    subscribes_to Events::EventUpvoted, Events::EventDownvoted

    class Count < ApplicationRecord
      self.table_name = "event_vote_counts"

      belongs_to :event
    end

    def call(fact)
      event_id = fact.payload.fetch(:event_id)
      column = fact.event_type == "Events::EventUpvoted" ? :upvotes : :downvotes

      record = Count.find_or_initialize_by(event_id: event_id)
      record.with_lock do
        record[column] += 1
        record.save!
      end
    end
  end
end
