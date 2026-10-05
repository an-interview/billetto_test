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

  test "is subscribed to the vote facts" do
    event = events(:upcoming)

    upvote(event).publish
    perform_enqueued_jobs

    assert_equal 1, count_for(event).upvotes
  end
end
