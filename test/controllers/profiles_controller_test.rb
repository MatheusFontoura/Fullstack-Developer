require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:member) }

  test "shows the signed in user's own profile" do
    get profile_path

    assert_response :success
    assert_select "body", text: /Ada Lovelace/
  end

  test "renders the edit form" do
    get edit_profile_path

    assert_response :success
  end

  test "updates the profile" do
    patch profile_path, params: { user: { full_name: "Ada King" } }

    assert_redirected_to profile_path
    assert_equal "Ada King", users(:member).reload.full_name
  end

  # The route has no id, so there is nothing to tamper with: a user cannot request
  # someone else's profile by changing a number. This asserts that stays true.
  test "always acts on the signed in user, never another one" do
    patch profile_path, params: { user: { full_name: "Ada King" } }

    assert_equal "Ada King", users(:member).reload.full_name
    assert_equal "Grace Hopper", users(:admin).reload.full_name
  end

  test "ignores a role the user tries to give themselves" do
    patch profile_path, params: { user: { full_name: "Ada King", role: "admin" } }

    assert_predicate users(:member).reload, :user?
  end

  test "keeps the existing password when the password fields are left blank" do
    digest = users(:member).password_digest

    patch profile_path, params: { user: { full_name: "Ada King", password: "", password_confirmation: "" } }

    assert_equal digest, users(:member).reload.password_digest
  end

  test "changes the password when a new one is given" do
    patch profile_path, params: {
      user: { password: "a-new-password", password_confirmation: "a-new-password" }
    }

    assert_predicate users(:member).reload.authenticate("a-new-password"), :present?
  end

  test "re-renders the form when the submission is invalid" do
    patch profile_path, params: { user: { email: "not-an-email" } }

    assert_response :unprocessable_content
    assert_equal "ada@umanni.test", users(:member).reload.email
  end

  test "attaches an avatar" do
    patch profile_path, params: { user: { avatar_image: fixture_file_upload("avatar.png", "image/png") } }

    assert_predicate users(:member).reload.avatar_image, :attached?
  end

  test "deletes the account and ends the session" do
    assert_difference -> { User.count }, -1 do
      delete profile_path
    end

    assert_redirected_to new_session_path
    assert_empty cookies[:session_id].to_s
  end

  test "rejects a submission that is not nested under a user key" do
    patch profile_path, params: { full_name: "Ada King" }

    assert_response :bad_request
  end

  test "is closed to visitors" do
    sign_out

    get profile_path

    assert_redirected_to new_session_path
  end
end
