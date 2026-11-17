class Borrowing < ApplicationRecord
  LOAN_PERIOD = 30.days
  DUE_SOON_NOTICE = 3.days

  belongs_to :book
  belongs_to :reader

  scope :active, -> { where(returned_at: nil) }

  before_validation :set_due_on, on: :create

  validates :borrowed_at, :due_on, presence: true
  validate :returned_after_borrowed

  def active?
    returned_at.nil?
  end

  private

  def set_due_on
    self.due_on ||= borrowed_at.to_date + LOAN_PERIOD if borrowed_at
  end

  def returned_after_borrowed
    return if returned_at.nil? || borrowed_at.nil? || returned_at >= borrowed_at

    errors.add(:returned_at, "cannot be earlier than borrowed_at")
  end
end
