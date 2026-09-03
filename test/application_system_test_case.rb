require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # Escape hatch for machines where Chrome is not on PATH (WSL, slim containers).
  Selenium::WebDriver::Chrome.path = ENV["CHROME_BINARY"] if ENV["CHROME_BINARY"].present?

  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  private
    # Deliberately shadows the cookie-jar helper the generator provides: that one writes
    # a cookie into a test request and a real browser never sees it.
    #
    # The assertion at the end is not decoration. `click_on` returns as soon as the click
    # is dispatched, so without waiting for the redirect the next `visit` outruns the
    # sign-in request and arrives as an anonymous visitor.
    def sign_in_as(user, password: "secret-password")
      visit new_session_path
      fill_in "Email", with: user.email
      fill_in "Password", with: password
      click_on "Sign in"

      assert_no_current_path new_session_path
    end
end
