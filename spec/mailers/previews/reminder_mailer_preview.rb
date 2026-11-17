# Preview at http://localhost:3000/rails/mailers/reminder_mailer
class ReminderMailerPreview < ActionMailer::Preview
  def due_soon
    ReminderMailer.due_soon(sample_borrowing(due_in: Borrowing::DUE_SOON_NOTICE))
  end

  def due_today
    ReminderMailer.due_today(sample_borrowing(due_in: 0.days))
  end

  private

  # Built in memory so previews work regardless of what is in the database.
  def sample_borrowing(due_in:)
    borrowed_at = Time.current - Borrowing::LOAN_PERIOD + due_in
    Borrowing.new(
      book: Book.new(serial_number: "123456", title: "The Pragmatic Programmer", author: "Andrew Hunt, David Thomas"),
      reader: Reader.new(card_number: "100001", full_name: "Jane Doe", email: "jane.doe@example.com"),
      borrowed_at: borrowed_at,
      due_on: borrowed_at.to_date + Borrowing::LOAN_PERIOD
    )
  end
end
