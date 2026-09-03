require "test_helper"

class Admin::DashboardsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:admin) }

  test "shows the total and the count for each role" do
    get admin_dashboard_path

    assert_response :success
    assert_select "#metric-total", text: User.count.to_s
    assert_select "#metric-admin", text: User.admin.count.to_s
    assert_select "#metric-user", text: User.user.count.to_s
  end

  test "subscribes to the dashboard stream" do
    get admin_dashboard_path

    assert_select "turbo-cable-stream-source"
  end

  test "counts a role with no members as zero rather than omitting it" do
    User.admin.where.not(id: users(:admin).id).destroy_all
    users(:admin).update!(role: :user)
    sign_out
    sign_in_as User.create!(
      full_name: "Katherine Johnson", email: "katherine@umanni.test", role: :admin,
      password: "secret-password", password_confirmation: "secret-password"
    )
    User.admin.where.not(email: "katherine@umanni.test").destroy_all

    get admin_dashboard_path

    assert_select "#metric-admin", text: "1"
  end

  test "is closed to users who are not admins" do
    sign_out
    sign_in_as users(:member)

    get admin_dashboard_path

    assert_redirected_to profile_url
  end
end
