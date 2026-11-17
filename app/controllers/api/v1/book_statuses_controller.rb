module Api
  module V1
    # Changes a book's status between "available" and "borrowed".
    #
    #   PATCH /api/v1/books/:serial_number/status
    #   { "status": "borrowed", "card_number": "100001" }
    #   { "status": "available" }
    class BookStatusesController < BaseController
      def update
        book = Book.find_by!(serial_number: params[:book_serial_number])

        case params.require(:status)
        when "borrowed"
          reader = Reader.find_by!(card_number: params.require(:card_number))
          book.borrow!(reader)
        when "available"
          book.return!
        else
          return render_error(:unprocessable_content, "status must be one of: #{Book::STATUSES.join(', ')}")
        end

        render json: BookSerializer.new(book.reload).as_json
      end
    end
  end
end
