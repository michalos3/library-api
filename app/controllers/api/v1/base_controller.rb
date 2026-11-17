module Api
  module V1
    class BaseController < ApplicationController
      DEFAULT_PER_PAGE = 25
      MAX_PER_PAGE = 100

      before_action :reject_null_bytes

      rescue_from ActionDispatch::Http::Parameters::ParseError do
        render_error :bad_request, "Request body is not valid JSON"
      end

      rescue_from ActiveRecord::RecordNotFound do |e|
        render_error :not_found, "#{e.model || 'Record'} not found"
      end

      rescue_from ActiveRecord::RecordInvalid do |e|
        render_error :unprocessable_content, "Validation failed", e.record.errors.to_hash(true)
      end

      # A duplicate that got past the uniqueness validation (two concurrent
      # requests) and was rejected by the unique index.
      rescue_from ActiveRecord::RecordNotUnique do
        render_error :conflict, "A record with the same unique value already exists"
      end

      rescue_from ActionController::ParameterMissing do |e|
        render_error :bad_request, e.message
      end

      rescue_from Book::StatusError do |e|
        render_error :conflict, e.message
      end

      private

      # PostgreSQL cannot store or compare strings with null bytes; without this
      # check such input would surface as a 500.
      def reject_null_bytes
        render_error :bad_request, "Parameters must not contain null bytes" if null_byte?(params.to_unsafe_h)
      end

      def null_byte?(value)
        case value
        when String then value.include?("\u0000")
        when Hash then value.any? { |key, nested| null_byte?(key) || null_byte?(nested) }
        when Array then value.any? { |nested| null_byte?(nested) }
        else false
        end
      end

      # Returns one page of the scope (`?page=`, `?per_page=`) and describes the
      # whole collection in response headers, so the body stays a plain array.
      def paginate(scope)
        page = [ params[:page].to_s.to_i, 1 ].max
        per_page = params[:per_page].to_s.to_i
        per_page = DEFAULT_PER_PAGE unless per_page.positive?
        per_page = [ per_page, MAX_PER_PAGE ].min
        total = scope.count
        total_pages = (total.to_f / per_page).ceil

        response.headers.merge!(
          "X-Total-Count" => total.to_s, "X-Total-Pages" => total_pages.to_s,
          "X-Page" => page.to_s, "X-Per-Page" => per_page.to_s
        )

        page > total_pages ? scope.none : scope.offset((page - 1) * per_page).limit(per_page)
      end

      def render_unknown_status
        render_error :unprocessable_content, "status must be one of: #{Book::STATUSES.join(', ')}"
      end

      def render_error(status, message, details = nil)
        body = { error: message }
        body[:details] = details if details.present?
        render json: body, status: status
      end
    end
  end
end
