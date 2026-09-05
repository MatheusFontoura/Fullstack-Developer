require "test_helper"

# Development is configured to run the same Solid adapters as production, which only
# helps if both are pointed at the same databases. This caught a real failure: cache.yml
# named the cache database under production alone, so in development the store looked
# for solid_cache_entries in the primary database and every rate-limited action raised
# on its first write. The test suite never saw it, because test uses :null_store.
class SolidStackTest < ActiveSupport::TestCase
  ENVIRONMENTS = %w[ development production ].freeze

  test "Solid Cache is pointed at the cache database everywhere it runs" do
    ENVIRONMENTS.each do |env|
      assert_equal "cache", Rails.application.config_for(:cache, env: env)[:database].to_s,
                   "#{env} runs Solid Cache without naming the cache database"
    end
  end

  test "Solid Cable is pointed at the cable database everywhere it runs" do
    ENVIRONMENTS.each do |env|
      config = Rails.application.config_for(:cable, env: env)

      assert_equal "solid_cable", config[:adapter].to_s, "#{env} is not using Solid Cable"
      assert_equal "cable", config.dig(:connects_to, :database, :writing).to_s,
                   "#{env} runs Solid Cable without naming the cable database"
    end
  end

  test "every Solid database is declared in database.yml" do
    ENVIRONMENTS.each do |env|
      databases = Rails.application.config_for(:database, env: env).keys.map(&:to_s)

      assert_equal %w[ cable cache primary queue ], databases.sort,
                   "#{env} is missing one of the Solid databases"
    end
  end
end
