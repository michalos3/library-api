require "rails_helper"

RSpec.describe "Readers API" do
  let(:json) { response.parsed_body }

  it "creates a reader" do
    post "/api/v1/readers", params: { reader: { card_number: "100001", full_name: "Jane Doe", email: "Jane@Example.com" } },
                            as: :json

    expect(response).to have_http_status(:created)
    expect(json).to eq("card_number" => "100001", "full_name" => "Jane Doe", "email" => "jane@example.com")
  end

  it "rejects a duplicate email regardless of case" do
    create(:reader, email: "jane@example.com")

    post "/api/v1/readers", params: { reader: { card_number: "100009", full_name: "Jane", email: "JANE@example.com" } },
                            as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(json["details"]).to have_key("email")
  end

  it "lists and shows readers" do
    create(:reader, card_number: "100002")
    create(:reader, card_number: "100001")

    get "/api/v1/readers"
    expect(response.parsed_body.pluck("card_number")).to eq(%w[100001 100002])

    get "/api/v1/readers/100002"
    expect(response.parsed_body["card_number"]).to eq("100002")
  end

  it "returns 404 for an unknown reader" do
    get "/api/v1/readers/999999"

    expect(response).to have_http_status(:not_found)
    expect(json["error"]).to eq("Reader not found")
  end

  it "returns 409 when a concurrent request has just created a reader with the same email" do
    create(:reader, email: "jane@example.com")
    # Losing the race: the uniqueness validation ran before the other request
    # committed, so only the unique index sees the duplicate.
    allow_any_instance_of(ActiveRecord::Validations::UniquenessValidator).to receive(:validate_each)

    post "/api/v1/readers", params: { reader: { card_number: "100009", full_name: "Jane", email: "jane@example.com" } },
                            as: :json

    expect(response).to have_http_status(:conflict)
    expect(json["error"]).to be_present
    expect(Reader.where(email: "jane@example.com").count).to eq(1)
  end
end
