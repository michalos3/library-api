require "rails_helper"

RSpec.describe "Book status API" do
  let(:json) { response.parsed_body }
  let!(:book) { create(:book, serial_number: "000001") }
  let!(:reader) { create(:reader, card_number: "100001") }

  def update_status(params)
    patch "/api/v1/books/000001/status", params: params, as: :json
  end

  describe "borrowing" do
    it "marks the book as borrowed by the reader for 30 days" do
      travel_to Time.zone.local(2026, 5, 1, 12) do
        update_status(status: "borrowed", card_number: "100001")
      end

      expect(response).to have_http_status(:ok)
      expect(json["status"]).to eq("borrowed")
      expect(json["current_borrowing"]).to include("due_on" => "2026-05-31")
      expect(json["current_borrowing"]["reader"]["card_number"]).to eq("100001")
    end

    it "returns 409 when the book is already borrowed" do
      book.borrow!(create(:reader))

      update_status(status: "borrowed", card_number: "100001")

      expect(response).to have_http_status(:conflict)
    end

    it "returns 404 for an unknown reader" do
      update_status(status: "borrowed", card_number: "999999")

      expect(response).to have_http_status(:not_found)
      expect(json["error"]).to eq("Reader not found")
    end

    it "requires the reader's card number" do
      update_status(status: "borrowed")

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "returning" do
    it "marks the book as available" do
      book.borrow!(reader)

      update_status(status: "available")

      expect(response).to have_http_status(:ok)
      expect(json).to include("status" => "available", "current_borrowing" => nil)
      expect(book.borrowings.last.returned_at).to be_present
    end

    it "returns 409 when the book is not borrowed" do
      update_status(status: "available")

      expect(response).to have_http_status(:conflict)
    end
  end

  it "rejects unknown statuses" do
    update_status(status: "lost")

    expect(response).to have_http_status(:unprocessable_content)
  end

  it "returns 404 for an unknown book" do
    patch "/api/v1/books/999999/status", params: { status: "available" }, as: :json

    expect(response).to have_http_status(:not_found)
  end
end
