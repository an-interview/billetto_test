require "test_helper"

class Events::EventVotedTest < ActiveSupport::TestCase
  test "upvote carries the voter and stream" do
    fact = Events::EventUpvoted.strict(data: { event_id: 7, user_id: "user_1" })

    assert_equal [ "Event$7", Events::VOTES_STREAM ], fact.stream_names
    assert_equal "user_1", fact.payload.fetch(:user_id)
  end

  test "downvote carries the voter and stream" do
    fact = Events::EventDownvoted.strict(data: { event_id: 9, user_id: "user_2" })

    assert_equal [ "Event$9", Events::VOTES_STREAM ], fact.stream_names
    assert_equal "user_2", fact.payload.fetch(:user_id)
  end

  test "links vote facts into the votes stream" do
    event = events(:upcoming)
    fact = Events::EventUpvoted.strict(data: { event_id: event.id, user_id: "user_1" })
    fact.publish

    linked = Rails.configuration.event_store.read.stream(Events::VOTES_STREAM).map(&:event_id)
    assert_equal [ fact.event_id ], linked
  end

  test "carries the direction it replaced" do
    fact = Events::EventUpvoted.strict(
      data: { event_id: 7, user_id: "user_1", previous_direction: "down" }
    )

    assert_equal "down", fact.payload.fetch(:previous_direction)
  end

  test "previous direction is optional" do
    fact = Events::EventUpvoted.strict(data: { event_id: 7, user_id: "user_1" })

    assert_nil fact.payload[:previous_direction]
  end

  test "withdrawal carries the voter, previous direction, and stream" do
    fact = Events::EventVoteWithdrawn.strict(
      data: { event_id: 7, user_id: "user_1", previous_direction: "up" }
    )

    assert_equal [ "Event$7", Events::VOTES_STREAM ], fact.stream_names
    assert_equal "user_1", fact.payload.fetch(:user_id)
    assert_equal "up", fact.payload.fetch(:previous_direction)
  end

  test "links withdrawal facts into the votes stream" do
    event = events(:upcoming)
    fact = Events::EventVoteWithdrawn.strict(
      data: { event_id: event.id, user_id: "user_1", previous_direction: "down" }
    )
    fact.publish

    linked = Rails.configuration.event_store.read.stream(Events::VOTES_STREAM).map(&:event_id)
    assert_equal [ fact.event_id ], linked
  end

  test "withdrawal requires the direction it replaced" do
    assert_raises(Fact::InvalidData) do
      Events::EventVoteWithdrawn.strict(data: { event_id: 7, user_id: "user_1" })
    end
  end

  test "requires a user id" do
    assert_raises(Fact::InvalidData) { Events::EventUpvoted.strict(data: { event_id: 7 }) }
  end
end
