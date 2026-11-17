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
end
