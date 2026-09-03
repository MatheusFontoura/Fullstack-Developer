ENV["RAILS_ENV"] ||= "test"

require "simplecov"

# Started before the application is loaded, otherwise everything that runs at boot
# is reported as uncovered.
SimpleCov.start "rails" do
  enable_coverage :branch

  skip %r{\A/test/}
  skip "app/channels/application_cable"
  skip "config/"

  group "Services", "app/services"
  group "Jobs", "app/jobs"

  # Parallel workers each write their own resultset; merging is what turns them back
  # into a single number instead of one worker's share.
  merging true
  merge_timeout 600

  # The brief asks for 90% line coverage. Branch coverage is measured and reported
  # but not enforced: failing a submission on a self-imposed threshold is a
  # self-inflicted red build.
  minimum_coverage line: 90 if ENV["CI"] || ENV["COVERAGE"]
end

require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)

    parallelize_setup do |worker|
      SimpleCov.command_name "#{SimpleCov.command_name}-#{worker}"
    end

    parallelize_teardown do
      SimpleCov.result
    end

    fixtures :all

    include ActiveJob::TestHelper
  end
end
