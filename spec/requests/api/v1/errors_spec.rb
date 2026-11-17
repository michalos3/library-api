require "rails_helper"

RSpec.describe "API error responses" do
  let(:json) { response.parsed_body }

  it "returns 400 in the API error format for a malformed JSON body" do
    post "/api/v1/books", params: '{"book": ', headers: { "CONTENT_TYPE" => "application/json" }

    expect(response).to have_http_status(:bad_request)
    expect(json).to eq("error" => "Request body is not valid JSON")
  end

  it "returns 404 in the API error format for an unknown route" do
    get "/api/v1/nope"

    expect(response).to have_http_status(:not_found)
    expect(json).to eq("error" => "Route not found")
  end

  it "returns 400 instead of crashing when a body parameter contains a null byte" do
    post "/api/v1/books", params: { book: { serial_number: "123456", title: "a\u0000b", author: "A" } }, as: :json

    expect(response).to have_http_status(:bad_request)
    expect(json).to eq("error" => "Parameters must not contain null bytes")
    expect(Book.count).to eq(0)
  end

  it "returns 400 instead of crashing when a query parameter contains a null byte" do
    get "/api/v1/books", params: { status: "borrowed\u0000" }

    expect(response).to have_http_status(:bad_request)
  end
end
