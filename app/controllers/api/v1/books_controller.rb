module Api
  module V1
    class BooksController < BaseController
      # GET /api/v1/books?status=available|borrowed
      def index
        books = Book.includes(current_borrowing: :reader).order(:serial_number)
        books = books.public_send(params[:status]) if Book::STATUSES.include?(params[:status])

        render json: books.map { |book| BookSerializer.new(book).as_json }
      end

      # GET /api/v1/books/:serial_number
      def show
        render json: BookSerializer.new(book).as_json(with_history: true)
      end

      # POST /api/v1/books
      def create
        book = Book.create!(book_params)

        render json: BookSerializer.new(book).as_json, status: :created
      end

      # DELETE /api/v1/books/:serial_number
      def destroy
        if book.destroy
          head :no_content
        else
          render_error :conflict, book.errors.full_messages.to_sentence
        end
      end

      private

      def book
        @book ||= Book.find_by!(serial_number: params[:serial_number])
      end

      def book_params
        params.expect(book: %i[serial_number title author])
      end
    end
  end
end
