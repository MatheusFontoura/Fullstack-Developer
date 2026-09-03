class SpreadsheetImportJob < ApplicationJob
  include ActiveJob::Continuable
  include ActionView::RecordIdentifier

  # A progress bar does not need to move once per row, and broadcasting per row would
  # put a thousand messages on the wire for a thousand-row file.
  BROADCAST_EVERY = 10

  # The dashboard is a coarser view than the bar, so it is refreshed less often.
  DASHBOARD_EVERY = 50

  def perform(spreadsheet_import)
    @import = spreadsheet_import

    step :prepare do
      with_reader { |reader| start_import(reader.row_count) }
    end

    step :import_rows do |step|
      with_reader { |reader| import_rows(reader, step) }
    end

    step :finish do
      persist(status: :completed)
      broadcast_progress
      broadcast_dashboard
    end
  # An interruption is the continuation working as designed: the worker is shutting
  # down and the job will resume from its cursor. Letting it fall through to the
  # rescue below would mark a healthy import as failed.
  rescue ActiveJob::Continuation::Interrupt
    raise
  rescue StandardError => error
    # The reason belongs on the record. Otherwise the admin sees a red badge and has to
    # be told to go read a jobs table to find out what went wrong.
    @import.update(status: :failed, failure_reason: "#{error.class}: #{error.message}".truncate(500))
    broadcast_progress
    broadcast_dashboard
    raise
  end

  private
    def start_import(row_count)
      @import.update!(
        status: :processing, total_rows: row_count,
        processed_rows: 0, failed_rows: 0, row_errors: []
      )
      broadcast_progress
    end

    def import_rows(reader, step)
      @row_errors = @import.row_errors.dup

      # Every created user would otherwise fire User's debounced dashboard refresh, and
      # that debounce restarts on each write: a run creating rows faster than the delay
      # produces no refresh at all until it finishes, which is precisely when a live
      # counter would be worth having. Suppressing the callback and pacing the refresh
      # here trades an unpredictable cadence for a fixed one.
      User.suppressing_turbo_broadcasts do
        reader.each_row do |attributes, line|
          index = line - (SpreadsheetImport::RowReader::HEADER_ROW + 1)
          next if index < step.cursor.to_i

          record_row(attributes, line)
          step.set!(index + 1)
          broadcast_batch(index + 1)
        end
      end

      # Deliberately no broadcast here: :finish sends one immediately afterwards, and
      # two messages a millisecond apart are not guaranteed to arrive in that order.
      # The loser overwrites the winner, and the page ends up stuck on "Processing".
      persist
    end

    def broadcast_batch(processed)
      if (processed % BROADCAST_EVERY).zero?
        persist
        broadcast_progress
      end

      broadcast_dashboard if (processed % DASHBOARD_EVERY).zero?
    end

    # A bad row is data, not an exception: it is counted, described and stepped over.
    # One malformed line in a thousand must not cost the other nine hundred.
    def record_row(attributes, line)
      user = User.new(attributes.merge(password: SecureRandom.base58(24)))
      # A role the file does not recognise is not worth failing a row over, and it is
      # certainly not worth trusting: unknown values become plain users.
      user.role = :user unless User.roles.key?(attributes[:role])

      if user.save
        SpreadsheetImport.update_counters(@import.id, processed_rows: 1)
      else
        SpreadsheetImport.update_counters(@import.id, processed_rows: 1, failed_rows: 1)
        @row_errors << { "line" => line, "message" => user.errors.full_messages.to_sentence }
      end
    end

    # Counters are incremented per row because they are cheap and the bar reads them.
    # The error list is written in batches, so a file of bad rows does not rewrite a
    # growing JSON column once per line.
    def persist(status: nil)
      @import.reload
      @import.update!({ row_errors: @row_errors || @import.row_errors, status: status }.compact)
    end

    def with_reader
      @import.file.open do |file|
        yield SpreadsheetImport::RowReader.new(file.path, extension: file_extension)
      end
    end

    def file_extension
      @import.file.filename.extension_without_delimiter.downcase
    end

    def broadcast_dashboard
      Turbo::StreamsChannel.broadcast_refresh_to(User::DASHBOARD_STREAM)
    end

    def broadcast_progress
      @import.broadcast_replace_to(
        @import,
        target: dom_id(@import, :progress),
        partial: "admin/spreadsheet_imports/progress",
        locals: { spreadsheet_import: @import }
      )
    end
end
