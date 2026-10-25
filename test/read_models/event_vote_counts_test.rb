require "test_helper"

class ReadModels::EventVoteCountsTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  def upvote(event, user_id: "u", previous: nil)
    Events::EventUpvoted.strict(
      data: { event_id: event.id, user_id: user_id, previous_direction: previous }
    )
  end

  def downvote(event, user_id: "u", previous: nil)
    Events::EventDownvoted.strict(
      data: { event_id: event.id, user_id: user_id, previous_direction: previous }
    )
  end

  def withdrawal(event, user_id: "u", previous: "up")
    Events::EventVoteWithdrawn.strict(
      data: { event_id: event.id, user_id: user_id, previous_direction: previous }
    )
  end

  def count_for(event)
    ReadModels::EventVoteCounts::Count.find_by(event_id: event.id)
  end

  test "counts upvotes and downvotes" do
    event = events(:upcoming)
    handler = ReadModels::EventVoteCounts.new

    handler.call(upvote(event, user_id: "a"))
    handler.call(upvote(event, user_id: "b"))
    handler.call(downvote(event, user_id: "c"))

    assert_equal 2, count_for(event).upvotes
    assert_equal 1, count_for(event).downvotes
  end

  test "is idempotent when the same fact is applied twice" do
    event = events(:upcoming)
    handler = ReadModels::EventVoteCounts.new
    fact = upvote(event, user_id: "user_1")

    handler.call(fact)
    handler.call(fact)

    assert_equal 1, count_for(event).upvotes
    assert_equal 1, ReadModels::EventVoteCounts::Count.where(event_id: event.id).count
  end

  test "counts distinct facts for the same new event without racing on the row" do
    event = events(:upcoming)
    handler = ReadModels::EventVoteCounts.new

    assert_nil count_for(event)

    handler.call(upvote(event, user_id: "a"))
    handler.call(upvote(event, user_id: "b"))

    assert_equal 1, ReadModels::EventVoteCounts::Count.where(event_id: event.id).count
    assert_equal 2, count_for(event).upvotes
  end

  test "a repeated vote for the same user does not change the tally" do
    event = events(:upcoming)
    handler = ReadModels::EventVoteCounts.new

    handler.call(upvote(event, user_id: "user_1"))
    handler.call(upvote(event, user_id: "user_1", previous: "up"))

    assert_equal 1, count_for(event).upvotes
    assert_equal 0, count_for(event).downvotes
  end

  test "switching a vote moves the tally to the new direction" do
    event = events(:upcoming)
    handler = ReadModels::EventVoteCounts.new

    handler.call(upvote(event, user_id: "user_1"))
    handler.call(downvote(event, user_id: "user_1", previous: "up"))

    assert_equal 0, count_for(event).upvotes
    assert_equal 1, count_for(event).downvotes
  end

  test "switch deltas are independent of application order" do
    event = events(:upcoming)
    handler = ReadModels::EventVoteCounts.new

    handler.call(downvote(event, user_id: "user_1", previous: "up"))
    handler.call(upvote(event, user_id: "user_1"))

    assert_equal 0, count_for(event).upvotes
    assert_equal 1, count_for(event).downvotes
  end

  test "withdrawal removes an upvote from the tally" do
    event = events(:upcoming)
    handler = ReadModels::EventVoteCounts.new

    handler.call(upvote(event, user_id: "user_1"))
    handler.call(withdrawal(event, user_id: "user_1", previous: "up"))

    assert_equal 0, count_for(event).upvotes
    assert_equal 0, count_for(event).downvotes
  end

  test "withdrawal removes a downvote from the tally" do
    event = events(:upcoming)
    handler = ReadModels::EventVoteCounts.new

    handler.call(downvote(event, user_id: "user_1"))
    handler.call(withdrawal(event, user_id: "user_1", previous: "down"))

    assert_equal 0, count_for(event).upvotes
    assert_equal 0, count_for(event).downvotes
  end

  test "withdrawal after a switch leaves both tallies at zero" do
    event = events(:upcoming)
    handler = ReadModels::EventVoteCounts.new

    handler.call(upvote(event, user_id: "user_1"))
    handler.call(downvote(event, user_id: "user_1", previous: "up"))
    handler.call(withdrawal(event, user_id: "user_1", previous: "down"))

    assert_equal 0, count_for(event).upvotes
    assert_equal 0, count_for(event).downvotes
  end

  test "withdrawal is idempotent when the same fact is applied twice" do
    event = events(:upcoming)
    handler = ReadModels::EventVoteCounts.new
    fact = withdrawal(event, user_id: "user_1", previous: "up")

    handler.call(upvote(event, user_id: "user_1"))
    handler.call(fact)
    handler.call(fact)

    assert_equal 0, count_for(event).upvotes
    assert_equal 0, count_for(event).downvotes
  end

  test "withdrawal deltas are independent of application order" do
    event = events(:upcoming)
    handler = ReadModels::EventVoteCounts.new

    handler.call(withdrawal(event, user_id: "user_1", previous: "up"))
    handler.call(upvote(event, user_id: "user_1"))

    assert_equal 0, count_for(event).upvotes
    assert_equal 0, count_for(event).downvotes
  end

  test "is subscribed to the vote facts" do
    event = events(:upcoming)

    upvote(event).publish
    perform_enqueued_jobs

    assert_equal 1, count_for(event).upvotes
  end

  test "is subscribed to withdrawal facts" do
    event = events(:upcoming)

    upvote(event).publish
    withdrawal(event, previous: "up").publish
    perform_enqueued_jobs

    assert_equal 0, count_for(event).upvotes
    assert_equal 0, count_for(event).downvotes
  end
end
