require "application_system_test_case"

# A page wider than the phone it is on is the one responsive bug you cannot see in a
# screenshot of the top of the page.
class ResponsiveTest < ApplicationSystemTestCase
  PHONE = [ 390, 844 ].freeze

  test "no signed-in screen scrolls sideways on a phone" do
    sign_in_as users(:admin)
    resize_to_phone

    [ admin_dashboard_path, admin_users_path, admin_spreadsheet_imports_path,
      new_admin_user_path, profile_path, edit_profile_path ].each do |path|
      visit path

      assert_no_horizontal_overflow path
    end
  end

  test "no signed-out screen scrolls sideways on a phone" do
    resize_to_phone

    [ new_session_path, new_registration_path, new_password_path ].each do |path|
      visit path

      assert_no_horizontal_overflow path
    end
  end

  # A pinned identity column that covers the buttons is worse than no pinned column:
  # everything still renders, and only the destructive action stays reachable.
  test "every action in the users table can be tapped on a phone" do
    sign_in_as users(:admin)
    resize_to_phone
    visit admin_users_path
    page.execute_script(%(document.querySelector('.table-scroll').scrollLeft = 9999))

    covered = page.evaluate_script(<<~'JS')
      [...document.querySelector("tbody tr").querySelectorAll("a, button")]
        .filter(el => {
          const box = el.getBoundingClientRect();
          const front = document.elementFromPoint(box.left + box.width / 2, box.top + box.height / 2);
          return !(front === el || el.contains(front));
        })
        .map(el => el.textContent.replace(/\s+/g, " ").trim());
    JS

    assert_empty covered, "these are covered by something else: #{covered.join(", ")}"
  end

  private
    def resize_to_phone
      page.driver.browser.manage.window.resize_to(*PHONE)
    end

    def assert_no_horizontal_overflow(path)
      document, viewport = page.evaluate_script("[document.body.scrollWidth, window.innerWidth]")

      assert_operator document, :<=, viewport, "#{path} is #{document - viewport}px wider than the screen"
    end
end
