# A group of interchangeable cars, e.g. "Skoda Fabia". Customers reserve a
# category, not a specific car, so `capacity` is the number of cars in it.
class CarCategory < ApplicationRecord
  has_many :reservations

  # case_sensitive: false mirrors the MySQL collation behind the unique index,
  # so "fabia" and "Fabia" fail here with a message instead of a DB error.
  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :daily_price, numericality: { only_integer: true, greater_than: 0 }
  validates :capacity, numericality: { only_integer: true, greater_than: 0 }
end
