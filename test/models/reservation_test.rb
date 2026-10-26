require "test_helper"

class ReservationTest < ActiveSupport::TestCase
  setup do
    @category = CarCategory.create!(name: "Test Car", daily_price: 1000, capacity: 1)
    @day1 = Date.current + 20
  end

  def day(n) = @day1 + (n - 1)

  def build(from, to, category: @category)
    category.reservations.new(customer_name: "Test", customer_email: "test@example.com",
                              start_date: from, end_date: to)
  end

  test "valid reservation saves" do
    assert build(day(1), day(3)).save
  end

  test "requires category, customer and dates" do
    reservation = Reservation.new
    assert_not reservation.valid?
    %i[car_category customer_name customer_email start_date end_date].each do |field|
      assert reservation.errors[field].any?, "#{field} should be required"
    end
  end

  test "rejects a malformed email" do
    reservation = build(day(1), day(3))
    reservation.customer_email = "not-an-email"
    assert_not reservation.valid?
    assert reservation.errors[:customer_email].any?
  end

  test "end date cannot be before start date, one-day rental is fine" do
    assert_not build(day(3), day(1)).valid?
    assert build(day(1), day(1)).valid?
  end

  test "start date cannot be in the past" do
    assert_not build(Date.current - 1, day(1)).valid?
    assert build(Date.current, Date.current).valid?
  end

  test "a running reservation can still be edited without moving its start" do
    reservation = build(Date.current - 2, Date.current + 2)
    reservation.save!(validate: false)
    reservation.customer_name = "New Name"
    assert reservation.valid?
    reservation.start_date = Date.current - 1
    assert_not reservation.valid?, "a changed start date must not be in the past"
  end

  test "lasts at most 30 days" do
    assert build(day(1), day(30)).valid?
    assert_not build(day(1), day(31)).valid?
  end

  test "rejects a reservation when no car is free on some day" do
    build(day(3), day(5)).save!
    reservation = build(day(5), day(8))
    assert_not reservation.valid?
    assert reservation.errors[:base].any?
    assert build(day(6), day(8)).valid?, "the day after the return is free"
  end

  test "accepts bookings that overlap the period but never coincide" do
    @category.update!(capacity: 2)
    build(day(1), day(3)).save!
    build(day(4), day(6)).save!
    build(day(7), day(10)).save!
    assert build(day(1), day(10)).valid?
  end

  test "editing does not count the reservation against itself" do
    reservation = build(day(1), day(3))
    reservation.save!
    reservation.end_date = day(5)
    assert reservation.valid?
  end

  test "moving to another category checks the new category" do
    full = CarCategory.create!(name: "Full Car", daily_price: 1000, capacity: 1)
    build(day(1), day(3), category: full).save!
    reservation = build(day(1), day(3))
    reservation.save!

    reservation.car_category = full
    assert_not reservation.valid?
    reservation.car_category = CarCategory.create!(name: "Free Car", daily_price: 1000, capacity: 1)
    assert reservation.valid?
  end

  test "locks the car category row while saving" do
    queries = []
    callback = ->(*, payload) { queries << payload[:sql] }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      build(day(1), day(3)).save!
    end
    lock_index = queries.index { |sql| sql.include?("car_categories") && sql.include?("FOR UPDATE") }
    insert_index = queries.index { |sql| sql.start_with?("INSERT INTO `reservations`") }
    assert lock_index, "the category row should be locked"
    assert lock_index < insert_index, "the lock should come before the insert"
  end

  test "total price is days times daily price" do
    assert_equal 3000, build(day(1), day(3)).total_price
  end
end
