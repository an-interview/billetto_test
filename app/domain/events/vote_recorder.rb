module Events
  # Records a vote as an EventUpvoted/EventDownvoted fact, carrying the voter's
  # Clerk user id for traceability.
  class VoteRecorder
    include Command::Handler

    handles CastVote, :cast

    private

    def cast(command)
      command.validate!
      event = ObjectRepository.find(command.tid)

      fact_for(command)
        .strict(data: { event_id: event.id, user_id: command.user_id })
        .publish
    end

    def fact_for(command)
      command.up? ? EventUpvoted : EventDownvoted
    end
  end
end
