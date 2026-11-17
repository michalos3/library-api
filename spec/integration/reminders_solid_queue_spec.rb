require "rails_helper"

# The other reminder specs use the Active Job test adapter. These run against
# the real Solid Queue adapter and its tables, as in development/production.
RSpec.describe "Reminders through Solid Queue" do
  let(:reader) { create(:reader, email: "jane@example.com") }
  let!(:borrowing) do
    create(:borrowing, reader: reader, borrowed_at: Borrowing::LOAN_PERIOD.ago)
  end

  before { ActionMailer::Base.deliveries.clear }

  def queue_adapter_for_test
    ActiveJob::QueueAdapters::SolidQueueAdapter.new
  end

  it "stores the delivery job in the queue tables, and running it delivers the email" do
    ReturnRemindersJob.perform_now

    job = SolidQueue::Job.sole
    expect(job.class_name).to eq("ReminderDeliveryJob")
    expect(borrowing.reload.due_today_reminder_enqueued_at).to be_present

    ActiveJob::Base.execute(job.arguments)

    expect(ActionMailer::Base.deliveries.map(&:to)).to eq([ [ "jane@example.com" ] ])
  end

  it "commits or rolls back the claim and the queued job together" do
    Borrowing.transaction(requires_new: true) do
      ReturnRemindersJob.perform_now
      raise ActiveRecord::Rollback
    end

    expect(SolidQueue::Job.count).to eq(0)
    expect(borrowing.reload.due_today_reminder_enqueued_at).to be_nil
  end
end
