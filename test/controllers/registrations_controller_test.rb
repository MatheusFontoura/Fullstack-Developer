require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "renders the registration form" do
    get new_registration_path

    assert_response :success
    assert_select "form[data-controller=form][data-form-submitting-value=?]", "Creating…"
  end

  test "registers a visitor and signs them in" do
    assert_difference -> { User.count }, 1 do
      post registration_path, params: { user: valid_attributes }
    end

    assert_redirected_to profile_path
    assert_predicate cookies[:session_id], :present?
  end

  test "ignores a role supplied by the visitor" do
    post registration_path, params: { user: valid_attributes.merge(role: "admin") }

    assert_predicate User.find_by(email: "katherine@umanni.test"), :user?
  end

  test "re-renders the form when the submission is invalid" do
    assert_no_difference -> { User.count } do
      post registration_path, params: { user: valid_attributes.merge(email: "not-an-email") }
    end

    assert_response :unprocessable_content
  end

  test "rejects a submission that is not nested under a user key" do
    assert_no_difference -> { User.count } do
      post registration_path, params: valid_attributes
    end

    assert_response :bad_request
  end

  private
    def valid_attributes
      {
        full_name: "Katherine Johnson",
        email: "katherine@umanni.test",
        password: "secret-password",
        password_confirmation: "secret-password"
      }
    end
end
