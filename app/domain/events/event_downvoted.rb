module Events
  class EventDownvoted < Fact
    SCHEMA = { event_id: Integer, user_id: String }.freeze

    def stream_names
      [ "Event$#{payload.fetch(:event_id)}", VOTES_STREAM ]
    end
  end
end
