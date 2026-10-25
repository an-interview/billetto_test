require "test_helper"

class ReadModels::CurrentVoteTest < ActiveSupport::TestCase
  def upvote(event, user_id: "user_1")
    Events::EventUpvoted.strict(data: { event_id: event.id, user_id: user_id })
  end

  def downvote(event, user_id: "user_1", previous: "up")
    Events::EventDownvoted.strict(
      data: { event_id: event.id, user_id: user_id, previous_direction: previous }
    )
  end

  def withdrawal(event, user_id: "user_1", previous: "up")
    Events::EventVoteWithdrawn.strict(
      data: { event_id: event.id, user_id: user_id, previous_direction: previous }
    )
  end

  def direction(event, user_id: "user_1")
    ReadModels::CurrentVote.direction(event_id: event.id, user_id: user_id)
  end

  test "returns nil when the user has no vote" do
    assert_nil direction(events(:upcoming))
  end

  test "returns the latest vote direction" do
    event = events(:upcoming)

    upvote(event).publish
    assert_equal "up", direction(event)

    downvote(event).publish
    assert_equal "down", direction(event)
  end

  test "returns nil after a withdrawal" do
    event = events(:upcoming)

    upvote(event).publish
    withdrawal(event).publish

    assert_nil direction(event)
  end

  test "ignores other users' votes" do
    event = events(:upcoming)

    upvote(event, user_id: "user_1").publish
    downvote(event, user_id: "user_2").publish

    assert_equal "up", direction(event, user_id: "user_1")
    assert_equal "down", direction(event, user_id: "user_2")
  end

  test "returns directions for a batch of events" do
    upcoming = events(:upcoming)
    past = events(:past)

    upvote(upcoming, user_id: "user_1").publish
    downvote(past, user_id: "user_1").publish

    directions = ReadModels::CurrentVote.directions(
      event_ids: [ upcoming.id, past.id ],
      user_id: "user_1"
    )

    assert_equal({ upcoming.id => "up", past.id => "down" }, directions)
  end
end
