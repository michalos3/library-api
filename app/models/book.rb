class Book < ApplicationRecord
  class StatusError < StandardError; end
  class AlreadyBorrowed < StatusError; end
  class NotBorrowed < StatusError; end

  STATUSES = %w[available borrowed].freeze

  has_many :borrowings, dependent: :delete_all
  has_one :current_borrowing, -> { active }, class_name: "Borrowing", inverse_of: :book

  validates :serial_number, presence: true, uniqueness: true,
                            format: { with: /\A\d{6}\z/, message: "must be a six-digit number" }
  validates :title, :author, presence: true

  before_destroy :ensure_not_borrowed, prepend: true

  scope :borrowed, -> { where(id: Borrowing.active.select(:book_id)) }
  scope :available, -> { where.not(id: Borrowing.active.select(:book_id)) }

  def borrowed?
    current_borrowing.present?
  end

  def status
    borrowed? ? "borrowed" : "available"
  end

  def borrow!(reader, at: Time.current)
    with_lock do
      raise AlreadyBorrowed, "Book #{serial_number} is already borrowed" if borrowed?

      borrowings.create!(reader: reader, borrowed_at: at).tap { reset_current_borrowing }
    end
  rescue ActiveRecord::RecordNotUnique
    # Lost a race with a concurrent request (guarded by the partial unique index).
    raise AlreadyBorrowed, "Book #{serial_number} is already borrowed"
  end

  def return!(at: Time.current)
    with_lock do
      borrowing = current_borrowing
      raise NotBorrowed, "Book #{serial_number} is not borrowed" unless borrowing

      borrowing.update!(returned_at: at)
      reset_current_borrowing
      borrowing
    end
  end

  private

  def reset_current_borrowing
    association(:current_borrowing).reset
  end

  def ensure_not_borrowed
    return unless borrowed?

    errors.add(:base, "cannot delete a book that is currently borrowed")
    throw :abort
  end
end
