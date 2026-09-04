require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "strips and downcases email" do
    user = User.new(email: "  DOWNCASED@Example.COM ")

    assert_equal "downcased@example.com", user.email
  end

  test "requires a full name, an email and a password" do
    user = User.new

    assert_predicate user, :invalid?
    assert_includes user.errors.attribute_names, :full_name
    assert_includes user.errors.attribute_names, :email
    assert_includes user.errors.attribute_names, :password
  end

  test "rejects a malformed email" do
    user = build(email: "not-an-email")

    assert_predicate user, :invalid?
    assert_includes user.errors.attribute_names, :email
  end

  test "rejects an email already taken by another user" do
    user = build(email: users(:member).email)

    assert_predicate user, :invalid?
    assert_includes user.errors.attribute_names, :email
  end

  test "rejects a password shorter than eight characters" do
    user = build(password: "short", password_confirmation: "short")

    assert_predicate user, :invalid?
    assert_includes user.errors.attribute_names, :password
  end

  test "defaults to the user role" do
    assert_predicate build.tap(&:save!), :user?
  end

  test "rejects a role outside the enum" do
    user = build(role: "superuser")

    assert_predicate user, :invalid?
    assert_includes user.errors.attribute_names, :role
  end

  test "stores the email encrypted at rest" do
    user = users(:member)
    stored = User.lease_connection.select_value(
      User.sanitize_sql([ "SELECT email FROM users WHERE id = ?", user.id ])
    )

    assert_not_equal user.email, stored
    assert_no_match(/ada@umanni\.test/, stored)
  end

  test "finds a user by email despite the column being encrypted" do
    assert_equal users(:member), User.find_by(email: "ada@umanni.test")
  end

  test "refuses to take the role from the last admin" do
    admin = only_admin

    assert_not admin.update(role: :user)
    assert_includes admin.errors.attribute_names, :role
    assert_predicate admin.reload, :admin?
  end

  test "refuses to destroy the last admin" do
    admin = only_admin

    assert_no_difference -> { User.count } do
      assert_not admin.destroy
    end

    assert_equal 1, User.admin.count
  end

  test "allows demoting an admin while another one remains" do
    users(:member).update!(role: :admin)

    assert users(:admin).update(role: :user)
  end

  test "destroys its sessions when destroyed" do
    user = users(:member)
    user.sessions.create!

    assert_difference -> { Session.count }, -1 do
      user.destroy
    end
  end

  private
    def only_admin
      User.admin.where.not(id: users(:admin).id).destroy_all
      users(:admin)
    end

    def build(**attributes)
      User.new({
        full_name: "Katherine Johnson",
        email: "katherine@umanni.test",
        password: "secret-password",
        password_confirmation: "secret-password"
      }.merge(attributes))
    end
end
