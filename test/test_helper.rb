ENV["RAILS_ENV"] ||= "test"

require "simplecov"

require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)

    # Each worker reports coverage under its own command name, then merges into the
    # parent result. Skipping this makes SimpleCov report only the last worker's share.
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
