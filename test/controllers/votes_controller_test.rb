require "test_helper"

class VotesControllerTest < ActionDispatch::IntegrationTest
  def facts_for(event)
    Rails.configuration.event_store.read.stream("Event$#{event.id}").to_a
  end

  def cast_vote(event, user_id:, direction:)
    Events::VoteRecorder.new.call(
      Events::CastVote.new(tid: event.tid, user_id: user_id, direction: direction)
    )
  end

  test "requires authentication" do
    post event_vote_url(events(:upcoming)), params: { direction: "up" }

    assert_redirected_to sign_in_url
    assert_empty facts_for(events(:upcoming))
  end

  test "records an upvote for a signed-in user" do
    event = events(:upcoming)

    post event_vote_url(event),
      params: { direction: "up" },
      headers: { "X-Test-Clerk-User-Id" => "user_1" }

    assert_redirected_to events_url
    assert_equal [ "Events::EventUpvoted" ], facts_for(event).map(&:event_type)
    assert_equal "user_1", facts_for(event).first.payload.fetch(:user_id)
  end

  test "records a downvote for a signed-in user" do
    event = events(:past)

    post event_vote_url(event),
      params: { direction: "down" },
      headers: { "X-Test-Clerk-User-Id" => "user_2" }

    assert_redirected_to events_url
    assert_equal [ "Events::EventDownvoted" ], facts_for(event).map(&:event_type)
  end

  test "handles an invalid direction with a friendly message" do
    event = events(:upcoming)

    post event_vote_url(event),
      params: { direction: "sideways" },
      headers: { "X-Test-Clerk-User-Id" => "user_1" }

    assert_redirected_to events_url
    assert_equal "That vote isn't valid.", flash[:alert]
    assert_empty facts_for(event)
  end

  test "withdrawal requires authentication" do
    event = events(:upcoming)
    cast_vote(event, user_id: "user_1", direction: "up")

    delete event_vote_url(event)

    assert_redirected_to sign_in_url
    assert_equal [ "Events::EventUpvoted" ], facts_for(event).map(&:event_type)
  end

  test "withdraws the signed-in user's active vote" do
    event = events(:upcoming)
    cast_vote(event, user_id: "user_1", direction: "up")

    delete event_vote_url(event), headers: { "X-Test-Clerk-User-Id" => "user_1" }

    assert_redirected_to events_url
    facts = facts_for(event)
    assert_equal [ "Events::EventUpvoted", "Events::EventVoteWithdrawn" ], facts.map(&:event_type)
    assert_equal "up", facts.last.payload.fetch(:previous_direction)
  end

  test "withdrawing without an active vote is a no-op" do
    event = events(:upcoming)

    delete event_vote_url(event), headers: { "X-Test-Clerk-User-Id" => "user_1" }

    assert_redirected_to events_url
    assert_empty facts_for(event)
  end
end
