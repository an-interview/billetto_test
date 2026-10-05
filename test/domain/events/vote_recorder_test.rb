require "test_helper"

class Events::VoteRecorderTest < ActiveSupport::TestCase
  def command(event, direction:, user_id: "user_1")
    Events::CastVote.new(tid: event.tid, user_id: user_id, direction: direction)
  end

  def facts_for(event)
    Rails.configuration.event_store.read.stream("Event$#{event.id}").to_a
  end

  test "records an upvote with the user id" do
    event = events(:upcoming)
    Events::VoteRecorder.new.call(command(event, direction: "up"))

    facts = facts_for(event)
    assert_equal [ "Events::EventUpvoted" ], facts.map(&:event_type)
    assert_equal "user_1", facts.first.payload.fetch(:user_id)
  end

  test "records a downvote" do
    event = events(:past)
    Events::VoteRecorder.new.call(command(event, direction: "down"))

    assert_equal [ "Events::EventDownvoted" ], facts_for(event).map(&:event_type)
  end

  test "rejects an unknown direction" do
    assert_raises(Command::ValidationError) do
      Events::VoteRecorder.new.call(command(events(:upcoming), direction: "sideways"))
    end
  end

  test "records only one vote per user per event" do
    event = events(:upcoming)

    2.times { Events::VoteRecorder.new.call(command(event, direction: "up")) }

    assert_equal [ "Events::EventUpvoted" ], facts_for(event).map(&:event_type)
  end

  test "switches an existing vote and records what it replaced" do
    event = events(:upcoming)

    Events::VoteRecorder.new.call(command(event, direction: "up"))
    Events::VoteRecorder.new.call(command(event, direction: "down"))

    facts = facts_for(event)
    assert_equal [ "Events::EventUpvoted", "Events::EventDownvoted" ], facts.map(&:event_type)
    assert_equal "up", facts.last.payload.fetch(:previous_direction)
  end

  test "records the first vote without a previous direction" do
    event = events(:upcoming)

    Events::VoteRecorder.new.call(command(event, direction: "up"))

    assert_nil facts_for(event).first.payload[:previous_direction]
  end

  test "keeps each user's vote separate" do
    event = events(:upcoming)

    Events::VoteRecorder.new.call(command(event, direction: "up", user_id: "user_1"))
    Events::VoteRecorder.new.call(command(event, direction: "up", user_id: "user_2"))

    assert_equal 2, facts_for(event).size
  end

  test "rejects an unknown event tid" do
    assert_raises(ObjectRepository::UnknownType) do
      Events::VoteRecorder.new.call(
        Events::CastVote.new(tid: "nope_1", user_id: "user_1", direction: "up")
      )
    end
  end
end
