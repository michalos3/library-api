# Delivers reminder emails enqueued with `deliver_later`.
#
# The stock ActionMailer::MailDeliveryJob does not retry and Solid Queue only
# parks failed jobs. A reminder is marked as sent when it is enqueued (see
# ReturnRemindersJob), so without retries a single failed delivery would lose
# the reminder for good.
class ReminderDeliveryJob < ActionMailer::MailDeliveryJob
  retry_on StandardError, wait: :polynomially_longer, attempts: 5

  # The loan was deleted in the meantime (book returned and removed from the
  # library) - there is nothing left to remind about.
  discard_on ActiveJob::DeserializationError
end
