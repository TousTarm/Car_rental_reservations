require "test_helper"

class ReservationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @reservation = reservations(:alice)
    @octavia = car_categories(:octavia)
  end

  def reservation_params(category: @octavia, from: Date.current + 30, to: Date.current + 32)
    { reservation: { car_category_id: category.id, customer_name: "Bob", customer_email: "bob@example.com",
                     start_date: from, end_date: to } }
  end

  test "index and show" do
    get reservations_path
    assert_response :success
    get reservation_path(@reservation)
    assert_response :success
  end

  test "new is prefilled from the URL" do
    get new_reservation_path(car_category_id: @octavia.id, start_date: Date.current + 5)
    assert_response :success
    assert_select "option[selected][value=?]", @octavia.id.to_s
    assert_select "input[name='reservation[start_date]'][value=?]", (Date.current + 5).to_s
  end

  test "creates a reservation" do
    assert_difference("Reservation.count") { post reservations_path, params: reservation_params }
    assert_redirected_to reservation_path(Reservation.last)
  end

  test "rejects a reservation over capacity" do
    post reservations_path, params: reservation_params
    assert_no_difference("Reservation.count") { post reservations_path, params: reservation_params }
    assert_response :unprocessable_entity
    assert_select ".alert", /No Skoda Octavia Combi is free/
  end

  test "updates a reservation" do
    get edit_reservation_path(@reservation)
    assert_response :success
    patch reservation_path(@reservation), params: { reservation: { end_date: @reservation.end_date + 1 } }
    assert_redirected_to reservation_path(@reservation)
    assert_equal @reservation.end_date + 1, @reservation.reload.end_date
  end

  test "rejects an invalid update" do
    patch reservation_path(@reservation), params: { reservation: { end_date: @reservation.start_date - 1 } }
    assert_response :unprocessable_entity
  end
end
