# Authentication backed by Clerk. `clerk` comes from Clerk::Authenticatable
# (populated by Clerk::Rack::Middleware from the request session).
module Authentication
  # Minimal user identity we attach to domain events.
  User = Data.define(:id)

  def current_user
    return @current_user if defined?(@current_user)

    @current_user = User.new(id: clerk.user_id) if clerk&.user?
  end

  def authenticated?
    current_user.present?
  end

  def require_authentication!
    return if authenticated?

    redirect_to sign_in_path, alert: "Sign in to continue"
  end
end
