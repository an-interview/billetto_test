module Events
  class EventImported < Fact
    SCHEMA = { event_id: Integer, external_id: String }.freeze

    def stream_names
      [ "Event$#{payload.fetch(:event_id)}" ]
    end
  end
end
