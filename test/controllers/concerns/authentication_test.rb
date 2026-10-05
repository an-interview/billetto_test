require "test_helper"

class AuthenticationTest < ActiveSupport::TestCase
  # Harness that includes the concern with a stubbed clerk.
  class Harness
    include Authentication

    FakeClerk = Struct.new(:user_id) do
      def user?
        !user_id.nil?
      end

      def session
        user_id ? { "sub" => user_id } : nil
      end
    end

    attr_reader :redirects

    def initialize(clerk)
      @clerk = clerk
      @redirects = []
    end

    def clerk
      @clerk
    end

    def sign_in_path
      "/sign-in"
    end

    def redirect_to(*args)
      @redirects << args
    end
  end

  test "unauthenticated when clerk has no session" do
    harness = Harness.new(Harness::FakeClerk.new(nil))

    assert_nil harness.current_user
    assert_not harness.authenticated?
  end

  test "current_user exposes the clerk user id when signed in" do
    harness = Harness.new(Harness::FakeClerk.new("user_123"))

    assert harness.authenticated?
    assert_equal "user_123", harness.current_user.id
  end

  test "require_authentication! redirects when signed out" do
    harness = Harness.new(Harness::FakeClerk.new(nil))
    harness.require_authentication!

    assert_equal [ [ "/sign-in", { alert: "Sign in to continue" } ] ], harness.redirects
  end

  test "require_authentication! passes when signed in" do
    harness = Harness.new(Harness::FakeClerk.new("user_123"))
    harness.require_authentication!

    assert_empty harness.redirects
  end
end
