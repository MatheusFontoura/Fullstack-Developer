require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # Escape hatch for machines where Chrome is not on PATH (WSL, slim containers).
  Selenium::WebDriver::Chrome.path = ENV["CHROME_BINARY"] if ENV["CHROME_BINARY"].present?

  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]
end
