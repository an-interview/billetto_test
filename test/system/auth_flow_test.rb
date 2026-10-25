require "application_system_test_case"

# Drives the sign-up / sign-in / sign-out flow and voting in a real browser.
#
# Clerk's hosted widget needs real keys and network access, so this test loads
# the local fake component (test/support/fake_clerk.js) and authenticates
# through the test-only /test/sign-in endpoint. Everything else — pages,
# redirects, session, authorization, voting and the read model — is real.
class AuthFlowSystemTest < ApplicationSystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  test "sign-in form mounts after Turbo navigation" do
    visit root_path
    click_link "Sign in"

    assert_current_path sign_in_path
    assert_selector "#clerk-sign-in form"
    assert_field "user_id"
  end

  test "sign-up form mounts after Turbo navigation" do
    visit root_path
    click_link "Sign up"

    assert_current_path sign_up_path
    assert_selector "#clerk-sign-up form"
    assert_field "user_id"
  end

  test "sign up, vote, sign out, then voting is restricted again" do
    event = events(:upcoming)

    visit sign_up_path
    fill_in "user_id", with: "user_browser"
    click_button "Create account"

    assert_current_path root_path
    assert_text "user_browser"

    within "#event_#{event.id}" do
      click_button "▲ Upvote"
    end

    within "#event_#{event.id}" do
      assert_text "1 total"
      click_button "Withdraw vote"
    end

    within "#event_#{event.id}" do
      assert_text "0 total"
    end

    click_button "Sign out"

    assert_current_path root_path
    assert_text "Sign in"

    first(:button, "▲ Upvote").click

    assert_current_path sign_in_path
  end

  test "sign in and sign out" do
    visit sign_in_path
    fill_in "user_id", with: "user_login"
    click_button "Sign in"

    assert_current_path root_path
    assert_text "user_login"

    click_button "Sign out"

    assert_current_path root_path
    assert_text "Sign in"
  end
end
