require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "sign in page renders" do
    get sign_in_url

    assert_response :success
    assert_select "h1", "Sign in"
    assert_select "#clerk-sign-in"
  end

  test "sign up page renders" do
    get sign_up_url

    assert_response :success
    assert_select "h1", "Sign up"
    assert_select "#clerk-sign-up"
  end

  test "sign out clears the session and redirects home" do
    delete sign_out_url

    assert_redirected_to root_url
  end

  test "header shows sign in links when signed out" do
    get root_url

    assert_select ".site-header__link", text: "Sign in"
    assert_select ".site-header__button", text: "Sign up"
  end

  test "header shows the user when signed in" do
    get root_url, headers: { "X-Test-Clerk-User-Id" => "user_123" }

    assert_select ".site-header__user", text: "user_123"
    assert_select ".site-header__button", text: "Sign out"
  end
end
