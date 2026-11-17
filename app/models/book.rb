class Book < ApplicationRecord
  # Declared before Lendable so that its (prepended) before_destroy guard runs
  # ahead of this dependent delete.
  has_many :borrowings, dependent: :delete_all

  include Lendable

  validates :serial_number, presence: true, uniqueness: true,
                            format: { with: /\A\d{6}\z/, message: "must be a six-digit number" }
  validates :title, :author, presence: true
end
