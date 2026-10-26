# A group of interchangeable cars, e.g. "Skoda Fabia". Customers reserve a
# category, not a specific car, so `capacity` is the number of cars in it.
class CarCategory < ApplicationRecord
  has_many :reservations

  # case_sensitive: false mirrors the MySQL collation behind the unique index,
  # so "fabia" and "Fabia" fail here with a message instead of a DB error.
  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :daily_price, numericality: { only_integer: true, greater_than: 0 }
  validates :capacity, numericality: { only_integer: true, greater_than: 0 }

  # How many cars stay free on every single day from start_date to end_date
  # (both inclusive). This is the one source of truth for availability: the
  # reservation validation and the availability list both call it.
  #
  # Counting reservations that overlap the period is not enough. With capacity
  # 2, bookings 1-3, 4-6 and 7-10 all overlap a 1-10 request, yet only one car
  # is ever taken at a time. What matters is the busiest day, so we count the
  # cars taken on each day and keep the maximum.
  #
  # `exclude` is the id of a reservation being edited, so it does not block itself.
  def free_units(start_date, end_date, exclude: nil)
    # Two date ranges overlap exactly when each one starts before the other ends.
    # Only these reservations can take a car on some day of the period.
    overlapping = reservations
      .where("start_date <= ? AND end_date >= ?", end_date, start_date)
      .where.not(id: exclude)
      .to_a

    # One pass per day is fine: a reservation is at most 30 days long.
    busiest_day = (start_date..end_date).map do |day|
      overlapping.count { |r| r.start_date <= day && day <= r.end_date }
    end.max

    capacity - busiest_day
  end

  # Price of renting one car for the period; both end days are paid.
  def price_for(start_date, end_date)
    ((end_date - start_date).to_i + 1) * daily_price
  end
end
