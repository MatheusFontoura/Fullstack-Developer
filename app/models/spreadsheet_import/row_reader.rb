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

    def row_count
      [ @sheet.last_row.to_i - HEADER_ROW, 0 ].max
    end

    # Yields each data row's attributes with its line number in the file, so an error
    # can point the admin at a row they can actually find.
    def each_row
      header = normalized_header

      ((HEADER_ROW + 1)..@sheet.last_row.to_i).each do |line|
        yield attributes_from(header, @sheet.row(line)), line
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
