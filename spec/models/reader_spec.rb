require "rails_helper"

RSpec.describe Reader do
  subject { build(:reader) }

  it { is_expected.to validate_presence_of(:full_name) }
  it { is_expected.to validate_uniqueness_of(:card_number).ignoring_case_sensitivity }
  it { is_expected.to validate_uniqueness_of(:email).ignoring_case_sensitivity }
  it { is_expected.to allow_value("123456").for(:card_number) }
  it { is_expected.not_to allow_values("12345", "1234567", "12345a").for(:card_number) }
  it { is_expected.not_to allow_value("not-an-email").for(:email) }

  it "normalizes email so uniqueness is case-insensitive" do
    create(:reader, email: "jane@example.com")

    duplicate = build(:reader, email: "  JANE@Example.com ")

    expect(duplicate.email).to eq("jane@example.com")
    expect(duplicate).not_to be_valid
  end
end
