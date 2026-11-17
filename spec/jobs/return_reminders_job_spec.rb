require "rails_helper"

RSpec.describe ReturnRemindersJob do
  let(:today) { Date.new(2026, 3, 1) }

  def borrowing_due_on(date, **attrs)
    create(:borrowing, borrowed_at: (date - Borrowing::LOAN_PERIOD).in_time_zone.change(hour: 10), **attrs)
  end

  around { |example| travel_to(today.in_time_zone.change(hour: 8)) { example.run } }

  it "sends a reminder 3 days before the due date" do
    borrowing = borrowing_due_on(today + 3)

    expect { described_class.perform_now }
      .to have_enqueued_mail(ReminderMailer, :due_soon).with(borrowing)
    expect(borrowing.reload.due_soon_reminder_enqueued_at).to be_present
  end

  it "sends a reminder on the due date" do
    borrowing = borrowing_due_on(today)

    expect { described_class.perform_now }
      .to have_enqueued_mail(ReminderMailer, :due_today).with(borrowing)
    expect(borrowing.reload.due_today_reminder_enqueued_at).to be_present
  end

  it "does not remind about other due dates or returned books" do
    borrowing_due_on(today + 2)
    borrowing_due_on(today + 4)
    borrowing_due_on(today - 1)
    borrowing_due_on(today + 3, returned_at: Time.current)
    borrowing_due_on(today, returned_at: Time.current)

    expect { described_class.perform_now }.not_to have_enqueued_mail
  end

  it "never sends the same reminder twice" do
    borrowing_due_on(today + 3)
    borrowing_due_on(today)

    expect { 2.times { described_class.perform_now } }.to have_enqueued_mail.exactly(2).times
  end

  it "retries a run that failed midway without losing the reminder" do
    borrowing = borrowing_due_on(today)
    allow_any_instance_of(ActionMailer::MessageDelivery).to receive(:deliver_later).and_raise(IOError, "queue is down")
    described_class.perform_later
    perform_enqueued_jobs(only: described_class) # the first run fails while enqueueing the email

    allow_any_instance_of(ActionMailer::MessageDelivery).to receive(:deliver_later).and_call_original

    expect { perform_enqueued_jobs(only: described_class) } # the retry
      .to have_enqueued_mail(ReminderMailer, :due_today).with(borrowing)
  end

  it "accepts the date to process" do
    borrowing = borrowing_due_on(today + 10)

    expect { described_class.perform_now(today + 7) }
      .to have_enqueued_mail(ReminderMailer, :due_soon).with(borrowing)
  end
end
