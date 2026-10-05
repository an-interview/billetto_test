module Events
  class EventUpvoted < Fact
    SCHEMA = { event_id: Integer, user_id: String }.freeze

    def stream_names
      [ "Event$#{payload.fetch(:event_id)}" ]
    end
  end
end
