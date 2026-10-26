require "test_helper"

class CarCategoryTest < ActiveSupport::TestCase
  setup do
    @category = CarCategory.create!(name: "Test Car", daily_price: 1000, capacity: 2)
    @day1 = Date.current + 20
  end

  # Saves without validations, so free_units is tested on its own and the
  # setup does not depend on the capacity check it is supposed to feed.
  def book(from, to, category: @category)
    reservation = category.reservations.new(customer_name: "Test", customer_email: "test@example.com",
                                            start_date: from, end_date: to)
    reservation.save!(validate: false)
    reservation
  end

  def day(n) = @day1 + (n - 1)

  test "requires a unique name, ignoring case" do
    assert_not CarCategory.new(name: "", daily_price: 1, capacity: 1).valid?
    assert_not CarCategory.new(name: "test car", daily_price: 1, capacity: 1).valid?
  end

  test "requires a positive whole daily price and capacity" do
    assert_not CarCategory.new(name: "A", daily_price: 0, capacity: 1).valid?
    assert_not CarCategory.new(name: "A", daily_price: 1, capacity: 0).valid?
    assert_not CarCategory.new(name: "A", daily_price: 1, capacity: 1.5).valid?
    assert CarCategory.new(name: "A", daily_price: 1, capacity: 1).valid?
  end

  test "free_units of an empty category is its capacity" do
    assert_equal 2, @category.free_units(day(1), day(5))
  end

  test "free_units is one less with one overlapping reservation" do
    book(day(3), day(8))
    assert_equal 1, @category.free_units(day(1), day(5))
  end

  test "free_units is zero when the category is exactly at capacity" do
    book(day(1), day(2))
    book(day(2), day(4))
    assert_equal 0, @category.free_units(day(1), day(5))
  end

  test "free_units looks at the busiest day, not at the number of overlaps" do
    # Three reservations overlap the period, but never two on the same day.
    book(day(1), day(3))
    book(day(4), day(6))
    book(day(7), day(10))
    assert_equal 1, @category.free_units(day(1), day(10))
  end

  test "free_units treats both end days as taken" do
    @category.update!(capacity: 1)
    book(day(1), day(3))
    assert_equal 0, @category.free_units(day(3), day(5)), "return day is still taken"
    assert_equal 1, @category.free_units(day(4), day(6)), "the next day is free"
  end

  test "free_units ignores the excluded reservation" do
    @category.update!(capacity: 1)
    reservation = book(day(1), day(3))
    assert_equal 1, @category.free_units(day(1), day(3), exclude: reservation.id)
  end

  test "free_units ignores reservations of other categories" do
    other = CarCategory.create!(name: "Other Car", daily_price: 1000, capacity: 1)
    book(day(1), day(5), category: other)
    assert_equal 2, @category.free_units(day(1), day(5))
  end

  test "price_for counts both end days" do
    assert_equal 3000, @category.price_for(day(1), day(3))
  end
end
