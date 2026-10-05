require "application_system_test_case"

class EventsVotingTest < ApplicationSystemTestCase
  test "listing shows events and vote controls" do
    visit events_path

    assert_text "Rails Meetup"
    assert_button "▲ Upvote"
    assert_button "▼ Downvote"
  end

  test "voting is restricted to signed-in users" do
    visit events_path

    first(:button, "▲ Upvote").click

    assert_current_path sign_in_path
    assert_text "Sign in"
  end
end
