SimpleCov.start "rails" do
  enable_coverage :branch

  add_filter %r{\A/test/}
  add_filter "app/channels/application_cable"
  add_filter "config/"

  add_group "Services", "app/services"
  add_group "Policies", "app/policies"
  add_group "Jobs", "app/jobs"

  # Parallel workers each write their own resultset; merging is what turns them
  # back into a single number. Without it the report reads ~1/N of reality.
  use_merging true
  merge_timeout 600

  # The brief asks for 90% line coverage. Branch coverage is measured and reported
  # but not enforced: failing a submission on a threshold nobody asked for is a
  # self-inflicted red build.
  minimum_coverage line: 90 if ENV["CI"] || ENV["COVERAGE"]
end
