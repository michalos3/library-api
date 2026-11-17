class BorrowingSerializer
  def initialize(borrowing)
    @borrowing = borrowing
  end

  def as_json(*)
    {
      borrowed_at: @borrowing.borrowed_at,
      due_on: @borrowing.due_on,
      returned_at: @borrowing.returned_at,
      reader: ReaderSerializer.new(@borrowing.reader).as_json
    }
  end
end
