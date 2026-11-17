require "rails_helper"

RSpec.describe Book do
  subject(:book) { create(:book) }

  let(:reader) { create(:reader) }

  describe "validations" do
    subject { build(:book) }

    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_presence_of(:author) }
    it { is_expected.to validate_uniqueness_of(:serial_number).ignoring_case_sensitivity }
    it { is_expected.to allow_value("000123").for(:serial_number) }
    it { is_expected.not_to allow_values("123", "1234567", "abcdef").for(:serial_number) }
  end

  describe "#borrow!" do
    it "creates an active borrowing due in 30 days" do
      travel_to Time.zone.local(2026, 1, 10, 12) do
        borrowing = book.borrow!(reader)

        expect(borrowing).to have_attributes(reader: reader, returned_at: nil, due_on: Date.new(2026, 2, 9))
        expect(book).to be_borrowed
        expect(book.status).to eq("borrowed")
      end
    end

    it "refuses to lend a book that is already borrowed" do
      book.borrow!(reader)

      expect { book.borrow!(create(:reader)) }.to raise_error(Book::AlreadyBorrowed)
      expect(book.borrowings.count).to eq(1)
    end

    it "is protected by the database against a concurrent borrow" do
      stale_copy = Book.find(book.id)
      book.borrow!(reader)
      # stale_copy has not loaded current_borrowing yet, but the row lock makes it
      # re-check; even bypassing the model the partial unique index rejects it.
      expect { stale_copy.borrow!(create(:reader)) }.to raise_error(Book::AlreadyBorrowed)
      expect { create(:borrowing, book: book) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe "#return!" do
    it "closes the active borrowing" do
      borrowing = book.borrow!(reader)

      book.return!

      expect(borrowing.reload.returned_at).to be_present
      expect(book).not_to be_borrowed
      expect(book.status).to eq("available")
    end

    it "fails when the book is not borrowed" do
      expect { book.return! }.to raise_error(Book::NotBorrowed)
    end

    it "allows the book to be borrowed again" do
      book.borrow!(reader)
      book.return!

      expect { book.borrow!(reader) }.to change { book.borrowings.count }.from(1).to(2)
    end
  end

  describe "scopes" do
    it "splits books into available and borrowed" do
      borrowed = create(:book).tap { |b| b.borrow!(reader) }
      returned = create(:book).tap { |b| create(:borrowing, :returned, book: b) }
      never_borrowed = create(:book)

      expect(Book.borrowed).to contain_exactly(borrowed)
      expect(Book.available).to contain_exactly(returned, never_borrowed)
    end
  end

  describe "#destroy" do
    it "deletes the book with its borrowing history" do
      create(:borrowing, :returned, book: book)

      expect { book.destroy }.to change(Book, :count).by(-1).and change(Borrowing, :count).by(-1)
    end

    it "refuses to delete a borrowed book" do
      book.borrow!(reader)

      expect(book.destroy).to be(false)
      expect(book.errors[:base]).to include("cannot delete a book that is currently borrowed")
      expect(Borrowing.count).to eq(1)
    end

    it "re-checks the status under a row lock, so a concurrent borrow is not deleted with the book" do
      stale_copy = Book.find(book.id)
      expect(stale_copy).not_to be_borrowed # status read before the concurrent borrow commits
      book.borrow!(reader)

      expect(stale_copy.destroy).to be(false)
      expect(Borrowing.count).to eq(1)
    end
  end
end
