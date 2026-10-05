require "test_helper"

class Billetto::EventMapperTest < ActiveSupport::TestCase
  PAYLOAD = {
    "id" => "abc-1",
    "title" => "Gig",
    "description" => "desc",
    "url" => "https://billetto.example/e/abc-1",
    "image_link" => "https://billetto.example/img/abc-1.png",
    "state" => "published",
    "type" => "concert",
    "availability" => true,
    "organizer" => { "id" => 7, "name" => "Org" },
    "location" => { "location_name" => "Hall", "city" => "Aarhus", "country_code" => "DK" },
    "startdate" => "2026-10-10T19:00:00Z",
    "enddate" => "2026-10-10T22:00:00Z"
  }.freeze

  test "maps api fields onto event attributes" do
    attributes = Billetto::EventMapper.to_attributes(PAYLOAD)

    assert_equal "abc-1", attributes[:external_id]
    assert_equal "Gig", attributes[:title]
    assert_equal "https://billetto.example/img/abc-1.png", attributes[:image_url]
    assert_equal "concert", attributes[:event_type]
    assert_equal "7", attributes[:organizer_id]
    assert_equal "Org", attributes[:organizer_name]
    assert_equal "Hall", attributes[:venue]
    assert_equal "Aarhus", attributes[:city]
    assert_equal "DK", attributes[:country_code]
    assert_equal true, attributes[:availability]
    assert_equal Time.zone.parse("2026-10-10T19:00:00Z"), attributes[:starts_at]
    assert_equal Time.zone.parse("2026-10-10T22:00:00Z"), attributes[:ends_at]
  end

  test "tolerates missing optional data" do
    attributes = Billetto::EventMapper.to_attributes({ "id" => 1, "title" => "X" })

    assert_equal "1", attributes[:external_id]
    assert_nil attributes[:organizer_name]
    assert_nil attributes[:venue]
    assert_nil attributes[:starts_at]
    assert_equal false, attributes[:availability]
  end

  test "accepts symbol keys and ignores unparseable timestamps" do
    attributes = Billetto::EventMapper.to_attributes({ id: 2, startdate: "not-a-date" })

    assert_equal "2", attributes[:external_id]
    assert_nil attributes[:starts_at]
  end

  test "reads the organiser and categorization fields used by the live API" do
    payload = {
      "id" => "9",
      "organiser" => { "id" => 5, "name" => "Live Org" },
      "categorization" => { "type" => "attraction" }
    }

    attributes = Billetto::EventMapper.to_attributes(payload)

    assert_equal "5", attributes[:organizer_id]
    assert_equal "Live Org", attributes[:organizer_name]
    assert_equal "attraction", attributes[:event_type]
  end
end
