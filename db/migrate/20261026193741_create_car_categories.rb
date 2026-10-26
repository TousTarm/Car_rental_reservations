# A car category is the bookable resource: customers reserve "a Skoda Fabia",
# not a specific car, so capacity is the number of cars in the category.
class CreateCarCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :car_categories do |t|
      t.string :name, null: false
      t.text :description
      # Whole Czech crowns; prices have no fractional part, so no decimal needed.
      t.integer :daily_price, null: false
      t.integer :capacity, null: false

      t.timestamps
    end
    # Backs the uniqueness validation, which alone can race.
    add_index :car_categories, :name, unique: true
  end
end
