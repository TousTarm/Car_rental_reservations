# A customer's booking of one car from a category for whole days,
# start_date and end_date both inclusive.
class Reservation < ApplicationRecord
  belongs_to :car_category

  validates :customer_name, presence: true
  validates :customer_email, presence: true,
    format: { with: URI::MailTo::EMAIL_REGEXP, allow_blank: true }
  validates :start_date, :end_date, presence: true
end
