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
    fact = Events::EventUpvoted.strict(data: { event_id: 7, user_id: "user_1" })
    fact.publish

    linked = Rails.configuration.event_store.read.stream(Events::VOTES_STREAM).map(&:event_id)
    assert_equal [ fact.event_id ], linked
  end

  test "requires a user id" do
    assert_raises(Fact::InvalidData) { Events::EventUpvoted.strict(data: { event_id: 7 }) }
  end
end
