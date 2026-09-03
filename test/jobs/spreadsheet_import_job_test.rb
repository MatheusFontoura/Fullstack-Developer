require "test_helper"

class SpreadsheetImportJobTest < ActiveJob::TestCase
  test "imports the valid rows of a csv and reports the rest" do
    import = build_import("users.csv")

    assert_difference -> { User.count }, 3 do
      SpreadsheetImportJob.perform_now(import)
    end

    import.reload

    assert_predicate import, :completed?
    assert_equal 5, import.total_rows
    assert_equal 5, import.processed_rows
    assert_equal 2, import.failed_rows
    assert_equal 3, import.imported_rows
    assert_equal 100, import.progress
  end

  test "imports an xlsx exactly as it imports a csv" do
    import = build_import("users.xlsx")

    assert_difference -> { User.count }, 3 do
      SpreadsheetImportJob.perform_now(import)
    end

    assert_equal 2, import.reload.failed_rows
  end

  test "names the line and the reason for every row it could not import" do
    import = build_import("users.csv")

    SpreadsheetImportJob.perform_now(import)

    errors = import.reload.row_errors

    assert_equal [ 5, 6 ], errors.map { |row_error| row_error["line"] }
    assert_match "Full name can't be blank", errors.first["message"]
    assert_match "Email has already been taken", errors.second["message"]
  end

  test "assigns the role from the file, defaulting anything unrecognised to user" do
    import = build_import("users.csv")

    SpreadsheetImportJob.perform_now(import)

    assert_predicate User.find_by(email: "katherine@umanni.test"), :admin?
    assert_predicate User.find_by(email: "dorothy@umanni.test"), :user?
    # Blank role in the file.
    assert_predicate User.find_by(email: "mary@umanni.test"), :user?
  end

  test "gives imported people an unguessable password rather than a shared one" do
    import = build_import("users.csv")

    SpreadsheetImportJob.perform_now(import)

    digests = User.where(email: %w[ katherine@umanni.test dorothy@umanni.test ]).pluck(:password_digest)

    assert_equal 2, digests.uniq.size
  end

  # The reason this job is continuable: a worker restarting mid-file would otherwise
  # replay rows it already imported, and every one of them would come back as a
  # duplicate email. Resuming from the cursor is correctness, not a nicety.
  test "resumes from its cursor rather than replaying imported rows" do
    import = build_import("users.csv")
    import.update!(status: :processing, total_rows: 5, processed_rows: 2)
    # Stand-ins for the two rows the interrupted run had already imported.
    %w[ katherine dorothy ].each do |name|
      User.create!(
        full_name: name.capitalize, email: "#{name}@umanni.test",
        password: "secret-password", password_confirmation: "secret-password"
      )
    end

    # Picks up as if the worker had died after the second row.
    assert_difference -> { User.count }, 1 do
      perform_resumed(import, completed: %w[ prepare ], current: [ "import_rows", 2 ])
    end

    assert_predicate import.reload, :completed?
    assert_not_nil User.find_by(email: "mary@umanni.test"), "the row at the cursor was skipped"
    # Replaying the first two rows would have produced duplicate-email failures.
    assert_equal 2, import.failed_rows
  end

  test "marks the import failed and re-raises when the file cannot be read" do
    import = build_import("not-an-image.txt", skip_validation: true)

    assert_raises StandardError do
      SpreadsheetImportJob.perform_now(import)
    end

    assert_predicate import.reload, :failed?
  end

  private
    def perform_resumed(import, completed:, current:)
      job = SpreadsheetImportJob.new(import)
      job.deserialize(job.serialize.merge("continuation" => { "completed" => completed, "current" => current }))
      job.perform_now
    end

    def build_import(fixture, skip_validation: false)
      import = users(:admin).spreadsheet_imports.new
      import.file.attach(io: file_fixture(fixture).open, filename: fixture)
      skip_validation ? import.save!(validate: false) : import.save!
      import
    end
end
