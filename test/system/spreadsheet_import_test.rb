require "application_system_test_case"

class SpreadsheetImportTest < ApplicationSystemTestCase
  setup { sign_in_as users(:admin) }

  test "uploads a spreadsheet and watches it finish without reloading" do
    visit new_admin_spreadsheet_import_path

    attach_file "Spreadsheet", file_fixture("users.csv")
    click_on "Start import"

    # The browser is on the progress page before the job runs, which is the whole
    # point: what follows arrives over the wire, not from a page load.
    assert_text "Pending"
    assert_selector "[role=progressbar][aria-valuenow='0']"

    assert_difference -> { User.count }, 3 do
      perform_enqueued_jobs
    end

    assert_text "Completed"
    assert_selector "[role=progressbar][aria-valuenow='100']"
    assert_text "5 of 5 rows"
  end

  test "reports the rows it could not import, by line and reason" do
    visit new_admin_spreadsheet_import_path
    attach_file "Spreadsheet", file_fixture("users.csv")
    click_on "Start import"

    assert_text "Pending"

    perform_enqueued_jobs

    assert_text "Rows that could not be imported"
    assert_text "Line 5"
    assert_text "Full name can't be blank"
    assert_text "Line 6"
    assert_text "Email has already been taken"
  end

  test "refuses a file that is not a spreadsheet" do
    visit new_admin_spreadsheet_import_path

    attach_file "Spreadsheet", file_fixture("not-an-image.txt")
    click_on "Start import"

    assert_text "File must be a .csv or .xlsx file"
  end

  test "lists finished imports" do
    visit new_admin_spreadsheet_import_path
    attach_file "Spreadsheet", file_fixture("users.xlsx")
    click_on "Start import"

    assert_text "Pending"

    perform_enqueued_jobs

    assert_text "Completed"

    click_on "All imports"

    assert_text "users.xlsx"
    assert_text "3 imported, 2 rejected"
  end
end
