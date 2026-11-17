module Api
  module V1
    class BaseController < ApplicationController
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

      def render_error(status, message, details = nil)
        body = { error: message }
        body[:details] = details if details.present?
        render json: body, status: status
      end
    end
  end
end
