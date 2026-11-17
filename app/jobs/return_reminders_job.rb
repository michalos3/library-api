# Runs once a day (see config/recurring.yml) and emails readers whose loan is
# due in DUE_SOON_NOTICE days or due today.
#
# Each reminder is "claimed" with an atomic conditional UPDATE before the email
# is enqueued, so running the job twice on the same day (a retry, a manual run,
# two schedulers) never sends the same reminder twice. The claim and the enqueue
# share a transaction (Solid Queue lives in the same database), so a run that
# fails midway rolls the claim back and the retry sends that reminder.
class ReturnRemindersJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 5

  REMINDERS = {
    due_soon: { column: :due_soon_reminder_sent_at, days_before_due: Borrowing::DUE_SOON_NOTICE },
    due_today: { column: :due_today_reminder_sent_at, days_before_due: 0.days }
  }.freeze

  def perform(date = Date.current)
    REMINDERS.each do |kind, config|
      due_on = date + config[:days_before_due]

      Borrowing.active.where(due_on: due_on, config[:column] => nil).find_each do |borrowing|
        Borrowing.transaction do
          ReminderMailer.public_send(kind, borrowing).deliver_later if claim(borrowing, config[:column])
        end
      end
    end
  end

  private

  def claim(borrowing, column)
    Borrowing.active.where(id: borrowing.id, column => nil)
             .update_all(column => Time.current, updated_at: Time.current) == 1
  end
end
