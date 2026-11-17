class ReminderMailer < ApplicationMailer
  self.delivery_job = ReminderDeliveryJob

  # Sent DUE_SOON_NOTICE (3 days) before the due date.
  def due_soon(borrowing)
    remind borrowing, subject: "Reminder: \"#{borrowing.book.title}\" is due on #{borrowing.due_on}"
  end

  # Sent on the due date.
  def due_today(borrowing)
    remind borrowing, subject: "Reminder: \"#{borrowing.book.title}\" is due today"
  end

  private

  def remind(borrowing, subject:)
    # Emails are delivered from a queue (and retried), so the book may have been
    # returned since the reminder was enqueued. Not calling `mail` sends nothing.
    return unless borrowing.active?

    @borrowing = borrowing
    mail to: borrowing.reader.email, subject: subject
  end
end
