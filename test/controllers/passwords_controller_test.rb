require "test_helper"

class PasswordsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = User.take }

  test "shows the form" do
    get new_password_path

    assert_response :success
  end

  test "enqueues the reset mail and says so without confirming the address" do
    post passwords_path, params: { password_reset: { email: @user.email } }

    assert_enqueued_email_with PasswordsMailer, :reset, args: [ @user ]
    assert_redirected_to new_session_path

    follow_redirect!

    assert_notice "reset instructions are on the way"
  end

  test "create for an unknown user redirects but sends no mail" do
    post passwords_path, params: { password_reset: { email: "missing-user@example.com" } }

    assert_enqueued_emails 0
    assert_redirected_to new_session_path

    follow_redirect!

    assert_notice "reset instructions are on the way"
  end

  test "opens the form for a valid token" do
    get edit_password_path(@user.password_reset_token)

    assert_response :success
  end

  test "refuses a token this application did not sign" do
    get edit_password_path("invalid token")

    assert_redirected_to new_password_path

    follow_redirect!

    assert_notice "reset link is invalid"
  end

  # A reset is what someone does when they have lost control of the account, so every
  # browser holding a session has to go — including the one asking.
  test "resetting the password signs every browser out" do
    @user.sessions.create!
    @user.sessions.create!

    assert_changes -> { @user.reload.password_digest } do
      put password_path(@user.password_reset_token), params: { password_reset: { password: "a-new-password", password_confirmation: "a-new-password" } }

      assert_redirected_to new_session_path
    end

    assert_empty @user.sessions.reload

    follow_redirect!

    assert_notice "Password has been reset"
  end

  test "refuses a confirmation that does not match" do
    token = @user.password_reset_token
    assert_no_changes -> { @user.reload.password_digest } do
      put password_path(token), params: { password_reset: { password: "no-match-here", password_confirmation: "different-one" } }
    end

    assert_response :unprocessable_content
    assert_notice "Password confirmation doesn't match Password"
  end

  test "update reports the real reason when the new password is too short" do
    assert_no_changes -> { @user.reload.password_digest } do
      put password_path(@user.password_reset_token), params: { password_reset: { password: "short", password_confirmation: "short" } }
    end

    assert_response :unprocessable_content
    assert_notice "Password is too short"
  end

  private
    def assert_notice(text)
      assert_select "div", /#{text}/
    end
end
