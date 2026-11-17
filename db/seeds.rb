# Sample data so the API can be explored right after `docker compose up`.
# Idempotent - safe to run more than once.

# `db:prepare` seeds a freshly created database, which in CI is the test one.
# Specs build their own data, so sample records must never end up there.
return if Rails.env.test?

readers = [
  { card_number: "100001", full_name: "Jane Doe", email: "jane.doe@example.com" },
  { card_number: "100002", full_name: "John Smith", email: "john.smith@example.com" },
  { card_number: "100003", full_name: "Anna Kowalska", email: "anna.kowalska@example.com" }
].map { |attrs| Reader.find_or_create_by!(card_number: attrs[:card_number]) { |r| r.assign_attributes(attrs) } }

books = [
  { serial_number: "000001", title: "The Pragmatic Programmer", author: "Andrew Hunt, David Thomas" },
  { serial_number: "000002", title: "Practical Object-Oriented Design in Ruby", author: "Sandi Metz" },
  { serial_number: "000003", title: "Designing Data-Intensive Applications", author: "Martin Kleppmann" },
  { serial_number: "000004", title: "Refactoring", author: "Martin Fowler" },
  { serial_number: "000005", title: "Domain-Driven Design", author: "Eric Evans" }
].map { |attrs| Book.find_or_create_by!(serial_number: attrs[:serial_number]) { |b| b.assign_attributes(attrs) } }

if Borrowing.none?
  # Returned borrowing - shows up in the history of book 000001.
  books[0].borrowings.create!(reader: readers[1], borrowed_at: 60.days.ago, returned_at: 45.days.ago)
  # Due in 3 days -> gets the "due soon" reminder.
  books[0].borrow!(readers[0], at: Borrowing::LOAN_PERIOD.ago + Borrowing::DUE_SOON_NOTICE)
  # Due today -> gets the "due today" reminder.
  books[1].borrow!(readers[2], at: Borrowing::LOAN_PERIOD.ago)
  # Recently borrowed - no reminder yet.
  books[2].borrow!(readers[1], at: 2.days.ago)
end
