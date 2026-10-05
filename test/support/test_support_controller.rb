# Test-only endpoints backing the browser test of the authentication flow.
#
# The real sign-in / sign-up UI is hosted JavaScript served by Clerk, which
# needs real keys and network access, so it cannot run in CI. Instead the test
# environment loads a local fake Clerk component (see test/support/fake_clerk.js)
# whose forms post here. This establishes the same session identity that
# TestClerkMiddleware understands, letting a real browser drive the flow.
#
# Routed only in the test environment (see config/routes.rb).
class TestSupportController < ActionController::Base
  layout false

  # The fake clerk-js is requested with crossorigin, which trips Rails' embedded
  # JS same-origin check. These endpoints are test-only, so skip it.
  skip_forgery_protection

  # POST /test/sign-in
  def create
    session[:test_clerk_user_id] = params[:user_id].presence || "test_user"
    redirect_to root_path
  end

  # GET /test/clerk.js
  def clerk
    response.headers["Cache-Control"] = "no-store"
    render plain: File.read(Rails.root.join("test/support/fake_clerk.js")),
           content_type: "text/javascript"
  end
end
