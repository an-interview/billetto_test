Rails.application.config.to_prepare do
  Clerk.configure do |config|
    # Keys default to ENV["CLERK_SECRET_KEY"] / ENV["CLERK_PUBLISHABLE_KEY"].
    config.logger = Rails.logger if Rails.env.development?
  end
end
