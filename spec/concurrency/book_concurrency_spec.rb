require "rails_helper"

# Real concurrency: every thread works on its own PostgreSQL connection, so
# these examples cannot run inside the usual per-example transaction and clean
# up after themselves instead.
RSpec.describe "Concurrent book operations" do
  self.use_transactional_tests = false

  after { [ Borrowing, Book, Reader ].each(&:delete_all) }

  # Runs the block in `count` threads that all start at the same moment.
  def in_parallel(count)
    start = Queue.new
    threads = Array.new(count) do |index|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          start.pop
          yield index
        end
      end
    end
    count.times { start << :go }
    threads.map(&:value)
  end

  it "lends a book to exactly one of many simultaneous borrowers" do
    book = create(:book)
    readers = create_list(:reader, 8)

    results = in_parallel(8) do |index|
      Book.find(book.id).borrow!(readers[index])
      :borrowed
    rescue Book::AlreadyBorrowed
      :refused
    end

    expect(results.tally).to eq(borrowed: 1, refused: 7)
    expect(Borrowing.active.where(book: book).count).to eq(1)
  end

  it "never deletes a book together with a loan that was just confirmed" do
    reader = create(:reader)

    lost_loans = Array.new(25) do
      book = create(:book)

      borrowed, = in_parallel(2) do |index|
        if index.zero?
          Book.find(book.id).borrow!(reader).present?
        else
          Book.find(book.id).destroy
        end
      rescue ActiveRecord::RecordNotFound
        false # the delete won the race; the borrow was refused with "not found"
      end

      borrowed && !Borrowing.active.exists?(book_id: book.id)
    end

    expect(lost_loans.count(true)).to eq(0)
  end
end
