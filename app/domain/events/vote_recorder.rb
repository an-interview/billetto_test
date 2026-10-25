module Events
  # Applies vote commands to an event's fact stream.
  #
  # Each user has at most one active vote per event:
  #
  # - a first vote records an +EventUpvoted+ or +EventDownvoted+ fact;
  # - repeating the active direction records nothing;
  # - the opposite direction records a new fact carrying +previous_direction+;
  # - +WithdrawVote+ records an +EventVoteWithdrawn+ fact when a vote exists.
  #
  # Votes are immutable facts. The active vote is derived from the latest vote
  # fact in the event's stream (see VoteHistory). Concurrent commands for the
  # same event and user are serialized with a transaction advisory lock, so the
  # second command sees the first command's committed vote instead of racing it.
  class VoteRecorder
    include Command::Handler

    handles CastVote, :cast
    handles WithdrawVote, :withdraw

    private

    # call-seq:
    #   cast(Events::CastVote.new(...))
    #
    # Records or switches the user's active vote. No fact is published when the
    # requested direction is already active.
    def cast(command)
      command.validate!
      event = ObjectRepository.find(command.tid)

      ApplicationRecord.transaction do
        lock_votes(event, command.user_id)
        current = VoteHistory.current_direction(event_id: event.id, user_id: command.user_id)
        next if current == command.direction

        publish(command, event, previous_direction: current)
      end
    end

    # call-seq:
    #   withdraw(Events::WithdrawVote.new(...))
    #
    # Removes the user's active vote. No fact is published when there is no
    # active vote, making withdrawal idempotent.
    def withdraw(command)
      command.validate!
      event = ObjectRepository.find(command.tid)

      ApplicationRecord.transaction do
        lock_votes(event, command.user_id)
        current = VoteHistory.current_direction(event_id: event.id, user_id: command.user_id)
        next unless current

        EventVoteWithdrawn
          .strict(
            data: {
              event_id: event.id,
              user_id: command.user_id,
              previous_direction: current
            }
          )
          .publish
      end
    end

    # Serializes concurrent vote and withdrawal commands for the same (event,
    # user) for the rest of the transaction, so the read below sees the other
    # command's committed fact.
    def lock_votes(event, user_id)
      sql = ApplicationRecord.sanitize_sql_array(
        [ "SELECT pg_advisory_xact_lock(hashtext(?), hashtext(?))", event.id.to_s, user_id.to_s ]
      )
      ApplicationRecord.connection.execute(sql)
    end

    # Publishes an upvote or downvote fact for the command's direction.
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
