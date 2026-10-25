require "test_helper"

class Events::VoteRecorderTest < ActiveSupport::TestCase
  def command(event, direction:, user_id: "user_1")
    Events::CastVote.new(tid: event.tid, user_id: user_id, direction: direction)
  end

  def withdraw_command(event, user_id: "user_1")
    Events::WithdrawVote.new(tid: event.tid, user_id: user_id)
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

  test "withdraws the active upvote" do
    event = events(:upcoming)
    recorder = Events::VoteRecorder.new

    recorder.call(command(event, direction: "up"))
    recorder.call(withdraw_command(event))

    facts = facts_for(event)
    assert_equal [ "Events::EventUpvoted", "Events::EventVoteWithdrawn" ], facts.map(&:event_type)
    assert_equal "up", facts.last.payload.fetch(:previous_direction)
  end

  test "withdraws the active downvote" do
    event = events(:upcoming)
    recorder = Events::VoteRecorder.new

    recorder.call(command(event, direction: "down"))
    recorder.call(withdraw_command(event))

    facts = facts_for(event)
    assert_equal [ "Events::EventDownvoted", "Events::EventVoteWithdrawn" ], facts.map(&:event_type)
    assert_equal "down", facts.last.payload.fetch(:previous_direction)
  end

  test "withdrawing without an active vote records nothing" do
    event = events(:upcoming)

    Events::VoteRecorder.new.call(withdraw_command(event))

    assert_empty facts_for(event)
  end

  test "withdrawing twice records only one withdrawal" do
    event = events(:upcoming)
    recorder = Events::VoteRecorder.new

    recorder.call(command(event, direction: "up"))
    2.times { recorder.call(withdraw_command(event)) }

    assert_equal 1, facts_for(event).count { |fact| fact.event_type == "Events::EventVoteWithdrawn" }
  end

  test "can vote again after withdrawing" do
    event = events(:upcoming)
    recorder = Events::VoteRecorder.new

    recorder.call(command(event, direction: "up"))
    recorder.call(withdraw_command(event))
    recorder.call(command(event, direction: "down"))

    facts = facts_for(event)
    assert_equal "Events::EventDownvoted", facts.last.event_type
    assert_nil facts.last.payload[:previous_direction]
  end

  test "withdrawal only clears the requesting user's vote" do
    event = events(:upcoming)
    recorder = Events::VoteRecorder.new

    recorder.call(command(event, direction: "up", user_id: "user_1"))
    recorder.call(command(event, direction: "down", user_id: "user_2"))
    recorder.call(withdraw_command(event, user_id: "user_1"))

    withdrawal = facts_for(event).last
    assert_equal "Events::EventVoteWithdrawn", withdrawal.event_type
    assert_equal "user_1", withdrawal.payload.fetch(:user_id)
    assert_equal "down", ReadModels::CurrentVote.direction(event_id: event.id, user_id: "user_2")
  end

  test "rejects an unknown event tid" do
    assert_raises(ObjectRepository::UnknownType) do
      Events::VoteRecorder.new.call(
        Events::CastVote.new(tid: "nope_1", user_id: "user_1", direction: "up")
      )
    end
  end
end
