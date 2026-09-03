# Demo data, and only ever demo data. The container entrypoint runs db:prepare, which
# seeds a freshly created database — so without this guard a production deploy would
# come up with a known email and a published password already in it.
#
# A real first admin belongs to the deploy, not to this file. The README shows the
# one-liner for creating it.
unless Rails.env.local?
  puts "Skipping demo seeds outside development and test."
  exit
end

# Idempotent: running it twice leaves the same database.
DEMO_USER_COUNT = 32
PASSWORD = "secret-password".freeze

[
  { full_name: "Grace Hopper", email: "admin@umanni.test", role: :admin },
  { full_name: "Ada Lovelace", email: "user@umanni.test", role: :user }
].each do |attributes|
  User.find_or_create_by!(email: attributes[:email]) do |user|
    user.assign_attributes(attributes.merge(password: PASSWORD, password_confirmation: PASSWORD))
  end
end

# Enough rows for sorting, filtering and the dashboard counters to be worth looking
# at. Driven by the total rather than by a fixed loop count, so a second run is a
# no-op instead of another thirty random people.
while User.count < DEMO_USER_COUNT
  User.create!(
    full_name: Faker::Name.name,
    email: Faker::Internet.unique.email(domain: "umanni.test"),
    role: Faker::Boolean.boolean(true_ratio: 0.2) ? :admin : :user,
    password: PASSWORD,
    password_confirmation: PASSWORD
  )
end

puts "Seeded #{User.count} users (#{User.admin.count} admins). Password for all: #{PASSWORD}"
