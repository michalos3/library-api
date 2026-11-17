class ReminderMailer < ApplicationMailer
  # Sent DUE_SOON_NOTICE (3 days) before the due date.
  def due_soon(borrowing)
    @borrowing = borrowing
    mail to: borrowing.reader.email,
         subject: "Reminder: \"#{borrowing.book.title}\" is due on #{borrowing.due_on}"
  end

  # Sent on the due date.
  def due_today(borrowing)
    @borrowing = borrowing
    mail to: borrowing.reader.email,
         subject: "Reminder: \"#{borrowing.book.title}\" is due today"
  end
end
