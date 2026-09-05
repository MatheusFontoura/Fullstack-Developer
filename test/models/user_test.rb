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

  test "destroys its sessions when destroyed" do
    user = users(:member)
    user.sessions.create!

    assert_difference -> { Session.count }, -1 do
      user.destroy
    end
  end

  private
    def build(**attributes)
      User.new({
        full_name: "Katherine Johnson",
        email: "katherine@umanni.test",
        password: "secret-password",
        password_confirmation: "secret-password"
      }.merge(attributes))
    end
end
