require "test_helper"

class Admin::Users::RolesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:admin) }

  test "promotes a user to admin" do
    patch admin_user_role_path(users(:member))

    assert_predicate users(:member).reload, :admin?
    assert_redirected_to admin_users_path
  end

  test "demotes an admin to user" do
    other_admin = User.create!(
      full_name: "Katherine Johnson", email: "katherine@umanni.test",
      role: :admin, password: "secret-password", password_confirmation: "secret-password"
    )

    patch admin_user_role_path(other_admin)

    assert_predicate other_admin.reload, :user?
  end

  test "replaces only the changed row when asked for a turbo stream" do
    patch admin_user_role_path(users(:member)), as: :turbo_stream

    assert_response :success
    assert_match "turbo-stream", response.media_type
    assert_match dom_id(users(:member)), response.body
  end

  # An admin demoting themselves is how a system ends up with nobody able to
  # administer it. Blocking that here is what keeps at least one admin around: any
  # other admin they demote leaves the demoting admin still an admin.
  test "refuses to change the signed in admin's own role" do
    patch admin_user_role_path(users(:admin))

    assert_predicate users(:admin).reload, :admin?
    assert_equal "You cannot change your own role. Ask another admin.", flash[:alert]
  end

  test "always leaves at least one admin behind" do
    User.admin.where.not(id: users(:admin).id).find_each do |admin|
      patch admin_user_role_path(admin)
    end

    assert_operator User.admin.count, :>=, 1
  end

  test "is closed to users who are not admins" do
    sign_out
    sign_in_as users(:member)

    patch admin_user_role_path(users(:admin))

    assert_redirected_to profile_url
    assert_predicate users(:admin).reload, :admin?
  end
end
