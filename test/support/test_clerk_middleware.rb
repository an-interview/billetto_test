# Test-only stand-in for Clerk::Rack::Middleware. The real middleware needs
# Clerk keys and performs a network handshake, so it is disabled in this
# environment (see CLERK_SKIP_RAILTIE in test.rb) and replaced with this
# double, which fabricates a Clerk session when the request carries a test id.
require "clerk/proxy"

class TestClerkMiddleware
  USER_ID_HEADER = "HTTP_X_TEST_CLERK_USER_ID"

  def initialize(app)
    @app = app
  end

  def call(env)
    # A request header works for integration tests; a session value is needed for
    # browser tests, where navigating cannot set a custom header.
    user_id = env[USER_ID_HEADER] || env["rack.session"]&.dig("test_clerk_user_id")
    env["clerk"] = Clerk::Proxy.new(session_claims: user_id ? { "sub" => user_id } : nil)
    @app.call(env)
  end
end
