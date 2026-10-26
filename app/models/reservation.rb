# A customer's booking of one car from a category for whole days,
# start_date and end_date both inclusive.
class Reservation < ApplicationRecord
  MAX_DAYS = 30

  belongs_to :car_category

  validates :customer_name, presence: true
  validates :customer_email, presence: true,
    format: { with: URI::MailTo::EMAIL_REGEXP, allow_blank: true }
  validates :start_date, :end_date, presence: true
  validate :end_date_not_before_start_date
  # Only on create or when the start moves: a running rental must stay editable.
  validate :start_date_not_in_past, if: -> { new_record? || start_date_changed? }
  validate :not_longer_than_max_days
  # Runs last and only on sane dates, so a broken form shows its own errors
  # instead of a confusing availability message.
  validate :car_available, if: -> { errors.empty? }

  def days
    (end_date - start_date).to_i + 1
  end

  def total_price
    car_category.price_for(start_date, end_date)
  end

  private

  def end_date_not_before_start_date
    return unless start_date && end_date
    errors.add(:end_date, "can't be before the start date") if end_date < start_date
  end

  def start_date_not_in_past
    return unless start_date
    errors.add(:start_date, "can't be in the past") if start_date < Date.current
  end

  def not_longer_than_max_days
    return unless start_date && end_date
    errors.add(:end_date, "is too far, a rental lasts at most #{MAX_DAYS} days") if days > MAX_DAYS
  end

  # Two customers may grab the last car at the same moment. Both would count
  # one free car and both would save. To prevent that we lock the category row
  # (SELECT ... FOR UPDATE) before counting. `save` runs validations inside its
  # own transaction, so the lock is held until the INSERT/UPDATE commits: the
  # second customer waits here and then counts the first one's reservation.
  # The count must see that fresh row, hence READ COMMITTED in database.yml.
  def car_available
    car_category.lock!
    return if car_category.free_units(start_date, end_date, exclude: id) >= 1

    errors.add(:base, "No #{car_category.name} is free for the whole period")
  end
end
