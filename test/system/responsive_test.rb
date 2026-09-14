require "application_system_test_case"

# A page wider than the phone it is on is the one responsive bug you cannot see in a
# screenshot of the top of the page.
class ResponsiveTest < ApplicationSystemTestCase
  PHONE = [ 390, 844 ].freeze
  DESKTOP = [ 1400, 1400 ].freeze

  # The browser is reused across tests in a worker, so a phone-sized window would
  # otherwise be inherited by whatever runs next.
  teardown { resize_window_to(*DESKTOP) }

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

  # truncate does nothing without a width to truncate to: the cell grew to the length of
  # the name and pushed every column after it off the screen, buttons included.
  test "a name at the length limit does not widen the table" do
    User.create!(full_name: "A" * 120, email: "long@umanni.test",
                 password: "secret-password", password_confirmation: "secret-password")
    sign_in_as users(:admin)
    resize_to_phone
    visit admin_users_path(query: "AAAA")

    assert_no_horizontal_overflow admin_users_path

    clipped = page.evaluate_script(<<~'JS')
      (() => { const p = document.querySelector("tbody tr p"); return p.scrollWidth > p.clientWidth; })()
    JS

    assert clipped, "the name was not truncated, so the cell grew to fit it"
  end

  # Reaching an action has to mean seeing it. A row wide enough to push the buttons past
  # the right edge leaves them behind a scrollbar nobody notices, and every other
  # assertion here still passes.
  test "every action in the users table can be tapped on a phone" do
    sign_in_as users(:admin)
    resize_to_phone
    visit admin_users_path

    unreachable = page.evaluate_script(<<~'JS')
      [...document.querySelector("tbody tr").querySelectorAll("a, button")]
        .filter(el => {
          const box = el.getBoundingClientRect();
          const front = document.elementFromPoint(box.left + box.width / 2, box.top + box.height / 2);
          const onScreen = box.left >= 0 && box.right <= window.innerWidth;
          return !onScreen || !(front === el || el.contains(front));
        })
        .map(el => el.textContent.replace(/\s+/g, " ").trim());
    JS

    assert_empty unreachable, "off screen or covered on a phone: #{unreachable.join(", ")}"
  end

  private
    def resize_to_phone
      resize_window_to(*PHONE)
    end

    def resize_window_to(width, height)
      page.driver.browser.manage.window.resize_to(width, height)
    end

    def assert_no_horizontal_overflow(path)
      document, viewport = page.evaluate_script("[document.body.scrollWidth, window.innerWidth]")

      assert_operator document, :<=, viewport, "#{path} is #{document - viewport}px wider than the screen"
    end
end
