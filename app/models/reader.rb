class Reader < ApplicationRecord
  has_many :borrowings, dependent: :restrict_with_error

  normalizes :email, with: ->(email) { email.strip.downcase }
  normalizes :full_name, with: ->(name) { name.squish }

  validates :card_number, presence: true, uniqueness: true,
                          format: { with: /\A\d{6}\z/, message: "must be a six-digit number" }
  validates :full_name, presence: true
  validates :email, presence: true, uniqueness: true,
                    format: { with: URI::MailTo::EMAIL_REGEXP }
end
