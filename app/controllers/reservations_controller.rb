# Reservations: listing, detail, booking and editing. All rules, including
# the capacity check, run as model validations on save.
class ReservationsController < ApplicationController
  before_action :set_reservation, only: %i[show edit update]

  def index
    @reservations = Reservation.includes(:car_category).order(:start_date)
  end

  def show
  end

  # Prefilled from the home page: chosen category and dates come in the URL.
  def new
    @reservation = Reservation.new(car_category_id: params[:car_category_id],
                                   start_date: params[:start_date], end_date: params[:end_date])
  end

  def create
    @reservation = Reservation.new(reservation_params)
    if @reservation.save
      redirect_to @reservation, notice: "Reservation was created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @reservation.update(reservation_params)
      redirect_to @reservation, notice: "Reservation was updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_reservation
    @reservation = Reservation.find(params[:id])
  end

  def reservation_params
    params.expect(reservation: %i[car_category_id customer_name customer_email start_date end_date])
  end
end
