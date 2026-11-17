# The timestamps are set when a reminder is put on the queue, not when the email
# is delivered, so the names should say that.
class RenameReminderSentAtToEnqueuedAt < ActiveRecord::Migration[8.1]
  def change
    rename_column :borrowings, :due_soon_reminder_sent_at, :due_soon_reminder_enqueued_at
    rename_column :borrowings, :due_today_reminder_sent_at, :due_today_reminder_enqueued_at
  end
end
