require "test_helper"

class CarCategoriesControllerTest < ActionDispatch::IntegrationTest
  test "home page lists categories" do
    get root_path
    assert_response :success
    assert_select ".card", CarCategory.count
  end

  test "home page shows availability for chosen dates" do
    # Octavia has one car; take it for the searched period.
    from, to = Date.current + 30, Date.current + 32
    car_categories(:octavia).reservations.create!(customer_name: "Bob", customer_email: "bob@example.com",
                                                  start_date: from, end_date: to)
    get root_path, params: { start_date: from, end_date: to }
    assert_response :success
    assert_select ".badge--full", "Sold out"
    assert_select ".badge--free", "2 of 2 free"
  end

  test "home page reports invalid dates" do
    get root_path, params: { start_date: Date.current - 1, end_date: Date.current }
    assert_response :success
    assert_select ".alert", /past/
    assert_select ".badge--free", 0
  end

  test "show lists the category's reservations" do
    get car_category_path(car_categories(:fabia))
    assert_response :success
    assert_select "td", "Alice Novak"
  end

  test "creates a category" do
    get new_car_category_path
    assert_response :success
    assert_difference("CarCategory.count") do
      post car_categories_path, params: { car_category: { name: "Skoda Kamiq", daily_price: 1100, capacity: 4 } }
    end
    assert_redirected_to car_category_path(CarCategory.last)
  end

  test "rejects an invalid category" do
    assert_no_difference("CarCategory.count") do
      post car_categories_path, params: { car_category: { name: "", daily_price: 0, capacity: 0 } }
    end
    assert_response :unprocessable_entity
  end
end
