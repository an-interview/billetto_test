require "test_helper"

class Events::ImporterTest < ActiveSupport::TestCase
  def payload(overrides = {})
    {
      "id" => "imp-1",
      "title" => "Imported Gig",
      "description" => "desc",
      "url" => "https://billetto.example/e/1",
      "image_link" => "https://billetto.example/img/1.png",
      "state" => "published",
      "type" => "concert",
      "availability" => true,
      "organizer" => { "id" => 7, "name" => "Org" },
      "location" => { "location_name" => "Hall", "city" => "Aarhus", "country_code" => "DK" },
      "startdate" => "2026-10-10T19:00:00Z",
      "enddate" => "2026-10-10T22:00:00Z"
    }.merge(overrides)
  end

  def importer(*payloads)
    Events::Importer.new(adapter: Billetto::FakeAdapter.new(events: payloads))
  end

  def command(limit: 50)
    Events::ImportPublicEvents.new(limit: limit)
  end

  test "creates events from api payloads" do
    result = importer(payload).call(command)

    assert_equal 1, result.imported
    assert_equal 0, result.skipped

    event = Event.find_by(external_id: "imp-1")
    assert_equal "Imported Gig", event.title
    assert_equal "Hall", event.venue
    assert_equal Time.zone.parse("2026-10-10T19:00:00Z"), event.starts_at
  end

  test "publishes an EventImported fact" do
    importer(payload).call(command)
    event = Event.find_by(external_id: "imp-1")

    facts = Rails.configuration.event_store.read.stream("Event$#{event.id}").to_a

    assert_equal 1, facts.size
    assert_equal "Events::EventImported", facts.first.event_type
    assert_equal event.id, facts.first.payload.fetch(:event_id)
  end

  test "is idempotent" do
    assert_equal 1, importer(payload).call(command).imported
    assert_equal 0, importer(payload).call(command).imported
    assert_equal 1, Event.where(external_id: "imp-1").count
  end

  test "re-publishes when the payload changes" do
    importer(payload).call(command)
    importer(payload("title" => "Renamed")).call(command)
    event = Event.find_by(external_id: "imp-1")

    assert_equal "Renamed", event.reload.title
    assert_equal 2, Rails.configuration.event_store.read.stream("Event$#{event.id}").to_a.size
  end

  test "skips payloads that fail validation" do
    result = importer(payload("title" => "")).call(command)

    assert_equal 0, result.imported
    assert_equal 1, result.skipped
    assert_nil Event.find_by(external_id: "imp-1")
  end

  test "rejects an invalid limit" do
    assert_raises(Command::ValidationError) { importer(payload).call(command(limit: 0)) }
  end
end
