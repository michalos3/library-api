require "rails_helper"

RSpec.describe "Books API" do
  let(:json) { response.parsed_body }
  let(:reader) { create(:reader, card_number: "100001", full_name: "Jane Doe", email: "jane@example.com") }

  describe "GET /api/v1/books" do
    it "lists all books with their availability" do
      borrowed = create(:book, serial_number: "000001")
      create(:book, serial_number: "000002")
      borrowed.borrow!(reader)

      get "/api/v1/books"

      expect(response).to have_http_status(:ok)
      expect(json.map { |b| [ b["serial_number"], b["status"] ] })
        .to eq([ %w[000001 borrowed], %w[000002 available] ])
      expect(json.first["current_borrowing"]).to include(
        "due_on" => borrowed.current_borrowing.due_on.iso8601,
        "reader" => { "card_number" => "100001", "full_name" => "Jane Doe", "email" => "jane@example.com" }
      )
      expect(json.second["current_borrowing"]).to be_nil
    end

    it "filters by status" do
      create(:book, serial_number: "000001").borrow!(reader)
      create(:book, serial_number: "000002")

      get "/api/v1/books", params: { status: "available" }

      expect(json.pluck("serial_number")).to eq([ "000002" ])
    end

    it "rejects an unknown status filter" do
      create(:book, serial_number: "000001")

      get "/api/v1/books", params: { status: "lost" }

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["error"]).to eq("status must be one of: available, borrowed")
    end

    it "returns the first 25 books by default and describes the pages in headers" do
      create_list(:book, 30)

      get "/api/v1/books"

      expect(json.size).to eq(25)
      expect(response.headers.to_h).to include(
        "x-total-count" => "30", "x-total-pages" => "2", "x-page" => "1", "x-per-page" => "25"
      )
    end

    it "returns the requested page" do
      (1..30).each { |n| create(:book, serial_number: format("%06d", n)) }

      get "/api/v1/books", params: { page: 2, per_page: 10 }

      expect(json.pluck("serial_number")).to eq((11..20).map { |n| format("%06d", n) })
      expect(response.headers["x-total-pages"]).to eq("3")
    end

    it "returns an empty list past the last page" do
      create_list(:book, 3)

      get "/api/v1/books", params: { page: 99_999_999_999 }

      expect(response).to have_http_status(:ok)
      expect(json).to eq([])
      expect(response.headers["x-total-count"]).to eq("3")
    end

    it "caps per_page at 100 and falls back to defaults for invalid values" do
      create_list(:book, 101)

      get "/api/v1/books", params: { per_page: 500 }
      expect(response.parsed_body.size).to eq(100)

      get "/api/v1/books", params: { page: "abc", per_page: "-5" }
      expect(response.parsed_body.size).to eq(25)
      expect(response.headers["x-page"]).to eq("1")
    end

    it "paginates within the status filter" do
      create_list(:book, 3).each { |book| book.borrow!(create(:reader)) }
      create_list(:book, 2)

      get "/api/v1/books", params: { status: "borrowed", per_page: 2 }

      expect(json.size).to eq(2)
      expect(response.headers["x-total-count"]).to eq("3")
    end

    it "does not run a query per book" do
      create_list(:book, 3).each { |book| book.borrow!(create(:reader)) }

      queries = []
      callback = ->(*, payload) { queries << payload[:sql] unless payload[:name] == "SCHEMA" }
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { get "/api/v1/books" }

      expect(queries.size).to be <= 4 # count + books + borrowings + readers
    end
  end

  describe "GET /api/v1/books/:serial_number" do
    it "returns the book with its full borrowing history, newest first" do
      book = create(:book, serial_number: "000001")
      old_reader = create(:reader, full_name: "Old Reader")
      create(:borrowing, book: book, reader: old_reader,
                         borrowed_at: Time.zone.local(2026, 1, 1, 10), returned_at: Time.zone.local(2026, 1, 15, 10))
      book.borrow!(reader)

      get "/api/v1/books/000001"

      expect(response).to have_http_status(:ok)
      expect(json["status"]).to eq("borrowed")
      expect(json["borrowings"].size).to eq(2)
      expect(json["borrowings"].first).to include("returned_at" => nil)
      expect(json["borrowings"].first["reader"]["full_name"]).to eq("Jane Doe")
      expect(json["borrowings"].second).to include(
        "borrowed_at" => Time.zone.local(2026, 1, 1, 10).as_json,
        "returned_at" => Time.zone.local(2026, 1, 15, 10).as_json,
        "due_on" => "2026-01-31"
      )
      expect(json["borrowings"].second["reader"]["full_name"]).to eq("Old Reader")
    end

    it "returns 404 for an unknown book" do
      get "/api/v1/books/999999"

      expect(response).to have_http_status(:not_found)
      expect(json["error"]).to eq("Book not found")
    end

    it "does not run a query per history entry" do
      book = create(:book, serial_number: "000001")
      create_list(:borrowing, 3, :returned, book: book)
      book.borrow!(reader)

      queries = []
      callback = ->(*, payload) { queries << payload[:sql] unless payload[:name] == "SCHEMA" }
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { get "/api/v1/books/000001" }

      expect(json["borrowings"].size).to eq(4)
      expect(queries.size).to be <= 5
    end
  end

  describe "POST /api/v1/books" do
    it "creates a book" do
      post "/api/v1/books", params: { book: { serial_number: "123456", title: "Eloquent Ruby", author: "Russ Olsen" } },
                            as: :json

      expect(response).to have_http_status(:created)
      expect(json).to include("serial_number" => "123456", "status" => "available")
      expect(Book.find_by(serial_number: "123456")).to be_present
    end

    it "accepts unwrapped attributes" do
      post "/api/v1/books", params: { serial_number: "123456", title: "Eloquent Ruby", author: "Russ Olsen" }, as: :json

      expect(response).to have_http_status(:created)
    end

    it "returns validation errors" do
      create(:book, serial_number: "123456")

      post "/api/v1/books", params: { book: { serial_number: "123456", title: "" } }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["details"].keys).to contain_exactly("serial_number", "title", "author")
    end

    it "returns 400 without book attributes" do
      post "/api/v1/books", params: {}, as: :json

      expect(response).to have_http_status(:bad_request)
    end

    it "returns 409 when a concurrent request has just created the same book" do
      create(:book, serial_number: "123456")
      # Losing the race: the uniqueness validation ran before the other request
      # committed, so only the unique index sees the duplicate.
      allow_any_instance_of(ActiveRecord::Validations::UniquenessValidator).to receive(:validate_each)

      post "/api/v1/books", params: { book: { serial_number: "123456", title: "Eloquent Ruby", author: "Russ Olsen" } },
                            as: :json

      expect(response).to have_http_status(:conflict)
      expect(json["error"]).to be_present
      expect(Book.where(serial_number: "123456").count).to eq(1)
    end
  end

  describe "DELETE /api/v1/books/:serial_number" do
    it "deletes an available book" do
      create(:book, serial_number: "000001")

      delete "/api/v1/books/000001"

      expect(response).to have_http_status(:no_content)
      expect(Book.count).to eq(0)
    end

    it "refuses to delete a borrowed book" do
      create(:book, serial_number: "000001").borrow!(reader)

      delete "/api/v1/books/000001"

      expect(response).to have_http_status(:conflict)
      expect(Book.count).to eq(1)
    end
  end
end
