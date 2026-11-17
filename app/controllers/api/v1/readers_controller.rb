module Api
  module V1
    class ReadersController < BaseController
      # GET /api/v1/readers?page=1&per_page=25
      def index
        render json: paginate(Reader.order(:card_number)).map { |reader| ReaderSerializer.new(reader).as_json }
      end

      # GET /api/v1/readers/:card_number
      def show
        render json: ReaderSerializer.new(reader).as_json
      end

      # POST /api/v1/readers
      def create
        reader = Reader.create!(reader_params)

        render json: ReaderSerializer.new(reader).as_json, status: :created
      end

      private

      def reader
        @reader ||= Reader.find_by!(card_number: params[:card_number])
      end

      def reader_params
        params.expect(reader: %i[card_number full_name email])
      end
    end
  end
end
