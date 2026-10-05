module Events
  # Records a vote as an EventUpvoted/EventDownvoted fact, carrying the voter's
  # Clerk user id for traceability and the direction it replaces.
  #
  # Each user has at most one active vote per event: casting the same direction
  # again records nothing, and switching directions records a fact that carries
  # the direction it replaced. Concurrent votes for the same (event, user) are
  # serialized with a transaction advisory lock, so the second command reads the
  # first's committed vote instead of racing it.
  class VoteRecorder
    include Command::Handler

    handles CastVote, :cast

    private

    def cast(command)
      command.validate!
      event = ObjectRepository.find(command.tid)

      ApplicationRecord.transaction do
        lock_votes(event, command.user_id)
        current = current_direction(event, command.user_id)
        next if current == command.direction

        publish(command, event, previous_direction: current)
      end
    end

    # Serializes concurrent votes for the same (event, user) for the rest of the
    # transaction, so the read below sees the other command's committed fact.
    def lock_votes(event, user_id)
      sql = ApplicationRecord.sanitize_sql_array(
        [ "SELECT pg_advisory_xact_lock(hashtext(?), hashtext(?))", event.id.to_s, user_id.to_s ]
      )
      ApplicationRecord.connection.execute(sql)
    end

    def current_direction(event, user_id)
      fact = Rails.configuration.event_store
        .read
        .stream("Event$#{event.id}")
        .to_a
        .reverse
        .find { |candidate| vote_fact?(candidate) && candidate.payload[:user_id].to_s == user_id.to_s }

      direction_for(fact)
    end

    def vote_fact?(fact)
      fact.event_type == EventUpvoted.name || fact.event_type == EventDownvoted.name
    end

    def direction_for(fact)
      return nil unless fact

      fact.event_type == EventUpvoted.name ? "up" : "down"
    end

    def publish(command, event, previous_direction:)
      fact_for(command)
        .strict(
          data: {
            event_id: event.id,
            user_id: command.user_id,
            previous_direction: previous_direction
          }
        )
        .publish
    end

    def fact_for(command)
      command.up? ? EventUpvoted : EventDownvoted
    end
  end
end
