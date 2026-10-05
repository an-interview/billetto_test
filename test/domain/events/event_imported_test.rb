require "test_helper"

class Events::EventImportedTest < ActiveSupport::TestCase
  def fact(event_id: 5, external_id: "x")
    Events::EventImported.strict(data: { event_id: event_id, external_id: external_id })
  end

  test "exposes its stream" do
    assert_equal [ "Event$5" ], fact.stream_names
  end

  test "rejects unknown keys" do
    assert_raises(Fact::InvalidData) do
      Events::EventImported.strict(data: { event_id: 5, external_id: "x", extra: 1 })
    end
  end

  test "publishes to its stream" do
    fact(event_id: 999).publish(Rails.configuration.event_store)

    assert_equal 1, Rails.configuration.event_store.read.stream("Event$999").to_a.size
  end
end
