# Car categories: the home page availability search, detail with reservations,
# and adding new categories. Availability itself is computed in CarCategory.
class CarCategoriesController < ApplicationController
  def index
    @categories = CarCategory.order(:daily_price)
    return if params[:start_date].blank? && params[:end_date].blank?

    # The search reuses the reservation's own date rules (no past, end after
    # start, max length), so a period offered here can also be booked.
    search = Reservation.new(start_date: params[:start_date], end_date: params[:end_date])
    search.validate
    @date_errors = search.errors.full_messages_for(:start_date) + search.errors.full_messages_for(:end_date)
    @start_date, @end_date = search.start_date, search.end_date if @date_errors.empty?
  end

  # Detail with a month calendar of free cars. Dates searched on the home page
  # come along in the URL and are highlighted in the calendar.
  def show
    @category = CarCategory.find(params[:id])
    @reservations = @category.reservations.order(:start_date)

    @start_date = parse_date(params[:start_date])
    @end_date = parse_date(params[:end_date])
    @month = parse_date("#{params[:month]}-01") || (@start_date || Date.current).beginning_of_month
    # Whole weeks, Monday to Sunday, so the calendar grid has no gaps.
    @free_by_day = @category.free_units_by_day(@month.beginning_of_week, @month.end_of_month.end_of_week)
  end

  def new
    @category = CarCategory.new
  end

  def create
    @category = CarCategory.new(category_params)
    if @category.save
      redirect_to @category, notice: "Car category was created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  # Dates come from the URL, so anything malformed simply counts as no date.
  def parse_date(value)
    Date.iso8601(value.to_s)
  rescue Date::Error
    nil
  end

  def category_params
    params.expect(car_category: %i[name description daily_price capacity])
  end
end
