require "test_helper"

class ReadModels::EventVoteCountsTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  def upvote(event, user_id: "u")
    Events::EventUpvoted.strict(data: { event_id: event.id, user_id: user_id })
  end

  def downvote(event, user_id: "u")
    Events::EventDownvoted.strict(data: { event_id: event.id, user_id: user_id })
  end

  def count_for(event)
    ReadModels::EventVoteCounts::Count.find_by(event_id: event.id)
  end

  test "counts upvotes and downvotes" do
    event = events(:upcoming)
    handler = ReadModels::EventVoteCounts.new

    handler.call(upvote(event))
    handler.call(upvote(event))
    handler.call(downvote(event))

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

  test "is subscribed to the vote facts" do
    event = events(:upcoming)

    upvote(event).publish
    perform_enqueued_jobs

    assert_equal 1, count_for(event).upvotes
  end
end
