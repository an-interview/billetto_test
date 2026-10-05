module ClerkHelper
  # Publishable key and derived Frontend API host, used to load clerk-js.
  # The key looks like "pk_test_<base64 of the frontend api host + '$'>".
  def clerk_publishable_key
    ENV["CLERK_PUBLISHABLE_KEY"].presence
  end

  def clerk_frontend_api
    key = clerk_publishable_key
    return if key.blank?

    Base64.decode64(key.split("_", 3).last).delete_suffix("$")
  end

  def clerk_enabled?
    clerk_publishable_key.present?
  end

  # The browser test loads a local fake instead of Clerk's CDN bundle.
  def clerk_js_url
    return "/test/clerk.js" if Rails.env.test?

    "https://#{clerk_frontend_api}/npm/@clerk/clerk-js@5/dist/clerk.browser.js"
  end
end
