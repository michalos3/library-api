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
        book = Book.includes(borrowings: :reader).find_by!(serial_number: params[:serial_number])

        render json: BookSerializer.new(book).as_json(with_history: true)
      end

      # POST /api/v1/books
      def create
        book = Book.create!(book_params)

        render json: BookSerializer.new(book).as_json, status: :created
      end

      # DELETE /api/v1/books/:serial_number
      def destroy
        book = Book.find_by!(serial_number: params[:serial_number])

        if book.destroy
          head :no_content
        else
          render_error :conflict, book.errors.full_messages.to_sentence
        end
      end

      private

      def book_params
        params.expect(book: %i[serial_number title author])
      end
    end
  end
end
