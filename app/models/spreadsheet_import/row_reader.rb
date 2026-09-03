class SpreadsheetImport
  # Turns a .csv or .xlsx into row hashes, so the job never has to know which of the
  # two it was handed.
  #
  # The extension is passed explicitly because Roo picks its parser from it, and an
  # Active Storage file arrives as a temp file whose path carries no useful suffix.
  #
  # Rows are read by index rather than streamed: `each_row_streaming` exists only on
  # Roo's xlsx backend, and one code path for both formats is worth more here than
  # streaming a file the model caps at 5 MB.
  class RowReader
    COLUMNS = %i[ full_name email role ].freeze
    HEADER_ROW = 1

    def initialize(path, extension:)
      @sheet = Roo::Spreadsheet.open(path.to_s, extension: extension.to_sym)
    end

    # Counted by walking the rows rather than trusting last_row: spreadsheets saved from
    # Excel routinely carry trailing empty rows, and counting those makes every one of
    # them a phantom rejected row and the progress bar wrong.
    def row_count
      count = 0
      each_row { count += 1 }
      count
    end

    # Yields each data row's attributes with its line number in the file, so an error
    # can point the admin at a row they can actually find.
    def each_row
      header = normalized_header

      ((HEADER_ROW + 1)..@sheet.last_row.to_i).each do |line|
        attributes = attributes_from(header, @sheet.row(line))
        next if attributes.values.all?(&:blank?)

        yield attributes, line
      end
    end

    private
      def normalized_header
        @sheet.row(HEADER_ROW).map { |cell| cell.to_s.strip.downcase.tr(" ", "_").to_sym }
      end

      def attributes_from(header, cells)
        attributes = header.zip(cells.map { |cell| cell.to_s.strip.presence }).to_h.slice(*COLUMNS)
        # "Admin" typed into Excel is the same role as "admin". Lowercasing here rather
        # than in the job keeps every value the reader hands out already normalised.
        attributes[:role] = attributes[:role]&.downcase
        attributes
      end
  end
end
