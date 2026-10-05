module Billetto
  # In-memory adapter used in tests (and as a safe default) so no network call
  # is made. Payloads are shaped like the real API response.
  class FakeAdapter
    EVENTS = [
      {
        "id" => "bil-1001",
        "object" => "public_event",
        "state" => "published",
        "title" => "Rails Meetup",
        "description" => "Talks about Rails",
        "url" => "https://billetto.example/e/1001",
        "image_link" => "https://billetto.example/img/1001.png",
        "availability" => true,
        "type" => "meetup",
        "organizer" => { "id" => 42, "name" => "Copenhagen Ruby" },
        "location" => { "location_name" => "Cafe", "city" => "Copenhagen", "country_code" => "DK" },
        "startdate" => "2026-09-01T18:00:00Z",
        "enddate" => "2026-09-01T21:00:00Z"
      }
    ].freeze

    def initialize(events: EVENTS)
      @events = events
    end

    # Mirrors the real adapter by paging through the whole set: `limit` is the
    # page size, and every event is returned regardless of how many pages it
    # spans.
    def list_public_events(limit: 10)
      page_size = [ limit.to_i, 1 ].max
      @events.each_slice(page_size).flat_map { |page| page.map(&:dup) }
    end
  end
end
