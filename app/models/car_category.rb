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
  # is ever taken at a time. What matters is the busiest day, so we take the
  # fewest free cars over all days of the period.
  #
  # `exclude` is the id of a reservation being edited, so it does not block itself.
  def free_units(start_date, end_date, exclude: nil)
    free_units_by_day(start_date, end_date, exclude: exclude).values.min
  end

  # Free cars for each day of the period, as { date => count }. free_units
  # and the availability calendar both read it, so they always agree.
  def free_units_by_day(start_date, end_date, exclude: nil)
    # Two date ranges overlap exactly when each one starts before the other ends.
    # Only these reservations can take a car on some day of the period.
    overlapping = reservations
      .where("start_date <= ? AND end_date >= ?", end_date, start_date)
      .where.not(id: exclude)
      .to_a

    # One pass per day over reservations already in memory: one query in total,
    # and the periods are short (a booking or a calendar page).
    (start_date..end_date).index_with do |day|
      capacity - overlapping.count { |r| r.start_date <= day && day <= r.end_date }
    end
  end

  # Price of renting one car for the period; both end days are paid.
  def price_for(start_date, end_date)
    ((end_date - start_date).to_i + 1) * daily_price
  end
end
