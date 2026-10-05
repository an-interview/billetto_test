require "test_helper"

class Billetto::FakeAdapterTest < ActiveSupport::TestCase
  test "returns fake events shaped like the API" do
    event = Billetto::FakeAdapter.new.list_public_events.first

    assert_equal "bil-1001", event["id"]
    assert_equal "Rails Meetup", event["title"]
  end

  test "honours the limit" do
    adapter = Billetto::FakeAdapter.new(events: [ { "id" => "1" }, { "id" => "2" } ])

    assert_equal 1, adapter.list_public_events(limit: 1).size
  end

  test "the configured adapter is the fake in test" do
    assert_instance_of Billetto::FakeAdapter, Billetto.adapter
  end
end
