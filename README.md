# Library API

A JSON API for library staff to manage books, track who borrowed them and send
return reminders. Built with Ruby 3.4, Rails 8.1 (API mode) and PostgreSQL 17.

## Quick start

```bash
docker compose up
```

The API runs at http://localhost:3000. On first boot the database is created,
migrated and seeded with sample readers and books (`db/seeds.rb`), including
loans that are due in 3 days and due today, so the reminders can be tried out
right away.

Run the test suite:

```bash
docker compose run --rm -e RAILS_ENV=test web bash -c "bin/rails db:prepare && bundle exec rspec"
```

## API

Books and readers are addressed by their natural, staff-facing identifiers:
the six-digit **serial number** and **library card number**, not database ids.
Both are stored as strings of exactly six digits, so leading zeros are allowed
and preserved (`000001` is a valid serial number).

| Method   | Path                                   | Description                                                 |
|----------|----------------------------------------|-------------------------------------------------------------|
| `GET`    | `/api/v1/books`                        | List books with their status (`?status=available\|borrowed` filters), paginated |
| `GET`    | `/api/v1/books/:serial_number`         | Book details with the full borrowing history                |
| `POST`   | `/api/v1/books`                        | Add a book                                                  |
| `DELETE` | `/api/v1/books/:serial_number`         | Delete a book                                               |
| `PATCH`  | `/api/v1/books/:serial_number/status`  | Change status: borrow or return                             |
| `GET`    | `/api/v1/readers`                      | List readers, paginated                                     |
| `GET`    | `/api/v1/readers/:card_number`         | Reader details                                              |
| `POST`   | `/api/v1/readers`                      | Add a reader                                                |

### Examples

```bash
# Add a book
curl -X POST localhost:3000/api/v1/books -H 'Content-Type: application/json' \
  -d '{"book": {"serial_number": "123456", "title": "Eloquent Ruby", "author": "Russ Olsen"}}'

# Lend it to a reader (card number 100001 exists in the seed data)
curl -X PATCH localhost:3000/api/v1/books/123456/status -H 'Content-Type: application/json' \
  -d '{"status": "borrowed", "card_number": "100001"}'

# Return it
curl -X PATCH localhost:3000/api/v1/books/123456/status -H 'Content-Type: application/json' \
  -d '{"status": "available"}'

# Book with its borrowing history
curl localhost:3000/api/v1/books/000001
```

```json
{
  "serial_number": "000001",
  "title": "The Pragmatic Programmer",
  "author": "Andrew Hunt, David Thomas",
  "status": "borrowed",
  "current_borrowing": {
    "borrowed_at": "2026-10-21T17:23:01.736+02:00",
    "due_on": "2026-11-20",
    "reader": { "card_number": "100001", "full_name": "Jane Doe", "email": "jane.doe@example.com" }
  },
  "borrowings": [
    {
      "borrowed_at": "2026-10-21T17:23:01.736+02:00",
      "due_on": "2026-11-20",
      "returned_at": null,
      "reader": { "card_number": "100001", "full_name": "Jane Doe", "email": "jane.doe@example.com" }
    },
    {
      "borrowed_at": "2026-09-18T17:23:01.693+02:00",
      "due_on": "2026-10-18",
      "returned_at": "2026-10-03T17:23:01.693+02:00",
      "reader": { "card_number": "100002", "full_name": "John Smith", "email": "john.smith@example.com" }
    }
  ]
}
```

The list endpoint returns the same shape without `borrowings`.

### Pagination

Both list endpoints take `?page=` (default 1) and `?per_page=` (default 25,
maximum 100). The body stays a plain JSON array. The collection is described in
the response headers `X-Total-Count`, `X-Total-Pages`, `X-Page` and
`X-Per-Page`. A page past the end returns an empty array, and invalid values
fall back to the defaults.

```bash
curl -i 'localhost:3000/api/v1/books?status=borrowed&page=2&per_page=10'
```

### Errors

Errors are returned as `{"error": "...", "details": {...}}`:

| Status | When                                                                          |
|--------|-------------------------------------------------------------------------------|
| `400`  | Required parameter missing (e.g. `card_number` when borrowing), malformed JSON body, null byte in a parameter |
| `404`  | Unknown book, reader or API path                                              |
| `409`  | Invalid state change: borrowing a borrowed book, returning an available book, deleting a borrowed book. Also a duplicate created by a concurrent request (caught by the unique index, not the validation) |
| `422`  | Validation errors (format, uniqueness, blank fields) or an unknown status (also in the `?status=` filter) |

## Return reminders

Loans last 30 days. `ReturnRemindersJob` runs **every day at 8:00 (Europe/Warsaw)**
and sends a reminder to readers whose book is due **in 3 days** and to readers
whose book is due **today**. It is scheduled with Solid Queue recurring tasks
(`config/recurring.yml`). Solid Queue runs inside the Puma process, so the single
`web` container serves the API and processes jobs.

No real emails are sent: in development the full email (recipient, subject,
body) is written to the log by a small custom delivery method
(`config/initializers/log_delivery.rb`).

- **See the emails:** trigger the job manually instead of waiting for 8:00 and
  check the logs:
  ```bash
  docker compose exec web bin/rails runner "ReturnRemindersJob.perform_now"
  docker compose logs web | grep -A12 "\[EMAIL\]"
  ```
- **Mailer previews:** http://localhost:3000/rails/mailers/reminder_mailer

## Design decisions

- **Borrowing history is its own table.** A `borrowings` row is one loan
  (`borrowed_at`, `due_on`, `returned_at`, reader). The book's status is not
  stored separately. It comes from whether an active (not returned) borrowing
  exists, so status and history cannot drift apart.
- **The database enforces the rules.** A partial unique index
  (`book_id WHERE returned_at IS NULL`) guarantees at most one active loan per
  book even under concurrent requests. Borrow, return and delete all take a row
  lock on the book, so a delete cannot race with a borrow and remove a book that
  was just lent. Six-digit identifiers and `returned_at >= borrowed_at` are additionally
  enforced with check constraints, and emails are normalized (trimmed,
  lowercased) so their uniqueness is case-insensitive.
- **Status change as a sub-resource.** `PATCH /books/:serial_number/status`
  matches the "update the book status: borrowed / available" requirement.
  Borrowing needs the reader's card number, because "borrowed" without "by
  whom" is incomplete. Invalid transitions return `409 Conflict`.
- **`due_on` is stored, not computed.** It is set when the book is lent
  (`borrowed_at` date + 30 days). Old loans keep their original due date if
  the loan period changes, and the reminder query is a plain indexed lookup.
- **Reminders are idempotent.** Each borrowing has `due_soon_reminder_enqueued_at` /
  `due_today_reminder_enqueued_at`. The job claims a reminder with an atomic
  conditional `UPDATE` before enqueueing the email, so a retried, manually
  triggered or duplicated run never enqueues the same reminder twice. The claim
  and the enqueue share one transaction, and the job itself is retried with
  backoff, so a run that fails midway does not lose reminders.
- **Enqueued is not delivered.** The columns record that a reminder was put on
  the queue, which is all the job can guarantee. Delivery happens later in
  `ReminderDeliveryJob`, which retries failures with backoff (the stock mail job
  does not retry) and re-checks the loan first: a book returned in the meantime
  gets no email. Delivery is therefore at-least-once: a worker that crashes
  right after sending could send the same email again on retry. A reminder that
  fails on every attempt stays in Solid Queue's failed jobs for manual retry
  and is not picked up by the next daily run.
- **Solid Queue instead of Sidekiq/cron.** Jobs and the schedule are stored in
  PostgreSQL, so the stack is just two containers. The Solid Queue tables live
  in the main database (a regular migration) rather than in the separate
  database Rails creates by default.
- **Deleting a book** removes it with its history but is refused while the book
  is on loan. Readers with history cannot be deleted (no endpoint either).
- **Readers endpoints** (create/list/show) go beyond the brief. They are needed
  to lend a book to someone.
- No serializer or pagination gems: three small serializer classes and one
  `paginate` helper in the base controller are enough at this size.

## Limitations and ideas for improvement

- **No authentication/authorization.** The brief allows this. In production I
  would put staff accounts with token auth in front of the API.
- **Reminders are exact-date.** If the scheduler is down for a whole day, that
  day's reminders are skipped rather than sent late. A catch-up window (e.g.
  "due within 3 days and not reminded yet") is a one-line change, but sending a
  "3 days left" email 1 day before the due date felt wrong. It depends on the
  product decision.
- **Overdue books** get no further reminders. A natural next step is a recurring
  overdue notice and an `?overdue=true` filter.
- **Search** by title/author for `GET /books`.
- **Soft delete** (or archiving) of books, if the borrowing history needs to be
  kept for reporting after a book is written off.
- **Real email delivery** (SMTP/SES) and a production Docker image. The compose
  setup runs the app in the development environment for easy review.
- **API documentation** as OpenAPI (e.g. rswag generated from request specs).

## Project layout

```
app/models/            Book, Reader, Borrowing; Book::Lendable holds the lending rules
                       (status, borrow!/return!, delete guard)
app/controllers/api/v1 Books, BookStatuses, Readers + shared error handling
app/serializers/       JSON representation
app/jobs/              ReturnRemindersJob, ReminderDeliveryJob (mail delivery with retries)
app/mailers/           ReminderMailer (+ text templates in app/views)
config/recurring.yml   Daily reminder schedule
spec/                  Model, request, job and mailer specs; mailer previews;
                       spec/concurrency (real parallel connections) and
                       spec/integration (real Solid Queue adapter)
```
