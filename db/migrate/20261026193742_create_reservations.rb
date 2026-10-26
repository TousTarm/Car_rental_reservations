class CreateReservations < ActiveRecord::Migration[8.1]
  def change
    create_table :reservations do |t|
      t.references :car_category, null: false, foreign_key: true
      t.string :customer_name, null: false
      t.string :customer_email, null: false
      # Whole days, both inclusive: the car is taken on start_date and returned on end_date.
      t.date :start_date, null: false
      t.date :end_date, null: false

      t.timestamps
    end
  end
end
