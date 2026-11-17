class BookSerializer
  def initialize(book)
    @book = book
  end

  def as_json(with_history: false)
    json = {
      serial_number: @book.serial_number,
      title: @book.title,
      author: @book.author,
      status: @book.status,
      current_borrowing: current_borrowing
    }
    json[:borrowings] = history if with_history
    json
  end

  private

  def current_borrowing
    borrowing = @book.current_borrowing
    BorrowingSerializer.new(borrowing).as_json.except(:returned_at) if borrowing
  end

  def history
    @book.borrowings.sort_by(&:borrowed_at).reverse.map { |b| BorrowingSerializer.new(b).as_json }
  end
end
