require "test_helper"

class FactTest < ActiveSupport::TestCase
  class SampleFact < Fact
    SCHEMA = { tid: String, count: Integer, note: [ String ] }.freeze

    def stream_names
      [ "Sample$#{payload.fetch(:tid)}" ]
    end
  end

  test "builds with valid data" do
    fact = SampleFact.strict(data: { tid: "a", count: 1 })

    assert_equal({ tid: "a", count: 1, note: nil }, fact.data)
    assert_equal "Sample$a", fact.stream_names.first
    assert_equal "FactTest::SampleFact", fact.event_type
  end

  test "accepts optional keys" do
    fact = SampleFact.strict(data: { tid: "a", count: 1, note: "hi" })

    assert_equal "hi", fact.payload[:note]
  end

  test "rejects unknown keys" do
    error = assert_raises(Fact::InvalidData) do
      SampleFact.strict(data: { tid: "a", count: 1, extra: true })
    end

    assert_match(/unknown keys/, error.message)
  end

  test "rejects missing required keys" do
    assert_raises(Fact::InvalidData) { SampleFact.strict(data: { tid: "a" }) }
  end

  test "rejects wrong types" do
    assert_raises(Fact::InvalidData) { SampleFact.strict(data: { tid: "a", count: "1" }) }
  end

  test "keeps a provided event id" do
    fact = SampleFact.strict(data: { tid: "a", count: 1 }, event_id: "fixed")

    assert_equal "fixed", fact.event_id
  end

  test "base Fact requires stream_names" do
    assert_raises(Fact::NotDefined) { Fact.new.stream_names }
  end
end
