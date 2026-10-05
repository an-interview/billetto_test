require "test_helper"

class EventTest < ActiveSupport::TestCase
  def build(**attributes)
    Event.new(
      { external_id: "test-1", title: "Gig", starts_at: Time.zone.parse("2026-01-01 20:00") }
        .merge(attributes)
    )
  end

  test "valid with required attributes" do
    assert build.valid?
  end

  test "requires an external_id" do
    event = build(external_id: nil)

    assert_not event.valid?
    assert_includes event.errors[:external_id], "can't be blank"
  end

  test "requires a unique external_id" do
    build.save!
    duplicate = build

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:external_id], "has already been taken"
  end

  test "requires a title" do
    assert_not build(title: nil).valid?
  end

  test "requires a starts_at" do
    assert_not build(starts_at: nil).valid?
  end

  test "rejects ends_at before starts_at" do
    event = build(ends_at: Time.zone.parse("2025-12-31 20:00"))

    assert_not event.valid?
    assert_includes event.errors[:ends_at], "must be after starts_at"
  end

  test "accepts ends_at after starts_at" do
    assert build(ends_at: Time.zone.parse("2026-01-01 22:00")).valid?
  end

  test "exposes a type id" do
    event = build
    event.save!

    assert_equal "event_#{event.id}", event.tid
  end

  test "is registered with ObjectRepository" do
    assert_equal Event, ObjectRepository.registered("event")
  end

  test "orders by starts_at" do
    assert_equal Event.ordered.pluck(:starts_at), Event.ordered.pluck(:starts_at).sort
  end
end
