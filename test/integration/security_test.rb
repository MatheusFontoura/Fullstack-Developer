require "test_helper"

# The brief names SQL injection, XSS and CSRF. The defences are Rails' own; these tests
# exist so that "Rails handles it" is a checked claim rather than a hope, and so that
# turning one of them off is a failing build rather than a quiet regression.
class SecurityTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:admin) }

  test "escapes markup that was stored in a user's name" do
    users(:member).update!(full_name: "<script>alert('xss')</script>")

    get admin_users_path

    assert_response :success
    assert_no_match "<script>alert", response.body
    assert_match "&lt;script&gt;alert", response.body
  end

  test "escapes markup echoed back into a validation message" do
    post admin_users_path, params: {
      user: { full_name: "<img src=x onerror=alert(1)>", email: "not-an-email",
              password: "secret-password", password_confirmation: "secret-password" }
    }

    assert_response :unprocessable_content
    assert_no_match "<img src=x", response.body
  end

  test "escapes markup carried by an import's row errors" do
    import = users(:admin).spreadsheet_imports.create!(
      file: { io: file_fixture("users.csv").open, filename: "users.csv" }
    )
    import.update!(row_errors: [ { "line" => 2, "message" => "<script>alert('row')</script>" } ])

    get admin_spreadsheet_import_path(import)

    assert_no_match "<script>alert('row')", response.body
  end

  # A wildcard reaching LIKE unescaped would turn a search box into "select everything".
  test "treats LIKE wildcards in a search term as literal characters" do
    get admin_users_path(query: "%")

    assert_response :success
    assert_select "td", text: /Ada Lovelace/, count: 0
  end

  test "does not let a search term reach the query as SQL" do
    get admin_users_path(query: "' OR 1=1 --")

    assert_response :success
    assert_select "td", text: /Ada Lovelace/, count: 0
    assert_predicate User, :any?, "the users table survived"
  end

  test "rejects a state-changing request that carries no CSRF token" do
    with_forgery_protection do
      assert_no_difference -> { User.count } do
        post registration_path, params: {
          user: { full_name: "Mallory", email: "mallory@umanni.test",
                  password: "secret-password", password_confirmation: "secret-password" }
        }
      end

      assert_response :unprocessable_content
    end
  end

  test "signs the session cookie so a forged one is ignored" do
    cookies[:session_id] = Session.first&.id || 1

    get admin_users_path

    assert_redirected_to new_session_path
  end

  private
    # Rails disables forgery protection in the test environment, which is convenient and
    # means the protection is never exercised. This turns it back on for one test.
    def with_forgery_protection
      original = ActionController::Base.allow_forgery_protection
      ActionController::Base.allow_forgery_protection = true
      yield
    ensure
      ActionController::Base.allow_forgery_protection = original
    end
end
