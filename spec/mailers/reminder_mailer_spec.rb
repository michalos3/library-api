require "rails_helper"

RSpec.describe ReminderMailer do
  let(:reader) { create(:reader, full_name: "Jane Doe", email: "jane@example.com") }
  let(:book) { create(:book, title: "Refactoring", author: "Martin Fowler", serial_number: "000042") }
  let(:borrowing) { create(:borrowing, book: book, reader: reader, borrowed_at: Time.zone.local(2026, 1, 1, 10)) }

  describe "#due_soon" do
    subject(:mail) { described_class.due_soon(borrowing) }

    it "is addressed to the reader and mentions the due date" do
      expect(mail.to).to eq([ "jane@example.com" ])
      expect(mail.subject).to eq('Reminder: "Refactoring" is due on 2026-01-31')
      expect(mail.body.encoded).to include("Dear Jane Doe", "due in 3 days, on 2026-01-31", "serial no. 000042")
    end
  end

  describe "#due_today" do
    subject(:mail) { described_class.due_today(borrowing) }

    it "is addressed to the reader and says the book is due today" do
      expect(mail.to).to eq([ "jane@example.com" ])
      expect(mail.subject).to eq('Reminder: "Refactoring" is due today')
      expect(mail.body.encoded).to include("due today (2026-01-31)")
    end
  end
end
