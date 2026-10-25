require "test_helper"

class Events::VoteHistoryTest < ActiveSupport::TestCase
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

  def current_direction(event, user_id: "user_1")
    Events::VoteHistory.current_direction(event_id: event.id, user_id: user_id)
  end

  test "returns nil when the user has no vote" do
    assert_nil current_direction(events(:upcoming))
  end

  test "returns the latest vote direction" do
    event = events(:upcoming)

    upvote(event).publish
    assert_equal "up", current_direction(event)

    downvote(event).publish
    assert_equal "down", current_direction(event)
  end

  test "returns nil after a withdrawal" do
    event = events(:upcoming)

    upvote(event).publish
    withdrawal(event).publish

    assert_nil current_direction(event)
  end

  test "ignores other users' votes" do
    event = events(:upcoming)

    upvote(event, user_id: "user_1").publish
    downvote(event, user_id: "user_2").publish

    assert_equal "up", current_direction(event, user_id: "user_1")
    assert_equal "down", current_direction(event, user_id: "user_2")
  end
end
