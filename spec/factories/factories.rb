FactoryBot.define do
  factory :reader do
    sequence(:card_number) { |n| format("%06d", 100_000 + n) }
    sequence(:full_name) { |n| "Reader #{n}" }
    sequence(:email) { |n| "reader#{n}@example.com" }
  end

  factory :book do
    sequence(:serial_number) { |n| format("%06d", n) }
    sequence(:title) { |n| "Book #{n}" }
    author { "Some Author" }
  end

  factory :borrowing do
    book
    reader
    borrowed_at { Time.current }

    trait :returned do
      returned_at { borrowed_at + 7.days }
    end
  end
end
