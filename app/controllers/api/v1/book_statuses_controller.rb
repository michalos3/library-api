module Api
  module V1
    # Changes a book's status between "available" and "borrowed".
    #
    #   PATCH /api/v1/books/:serial_number/status
    #   { "status": "borrowed", "card_number": "100001" }
    #   { "status": "available" }
    class BookStatusesController < BaseController
      # An unknown book is a 404 even when the request body is invalid.
      before_action :book

      def update
        case params.require(:status)
        when "borrowed"
          book.borrow!(reader)
        when "available"
          book.return!
        else
          return render_unknown_status
        end

        render json: BookSerializer.new(book.reload).as_json
      end

      private

      def book
        @book ||= Book.find_by!(serial_number: params[:book_serial_number])
      end

      def reader
        @reader ||= Reader.find_by!(card_number: params.require(:card_number))
      end
    end
  end
end
