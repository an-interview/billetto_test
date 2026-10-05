require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # The Clerk UI is driven by JavaScript, but the flows we assert here do not
  # need a real browser. Set SELENIUM=1 to run against headless Chrome.
  if ENV["SELENIUM"]
    driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]
  else
    driven_by :rack_test
  end
end
