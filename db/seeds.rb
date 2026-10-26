# Sample data for trying the app right after `bin/rails db:setup`.
# Dates are relative to today, so the scenarios never fall into the past.
# Everything goes through create!, so the data also pass all validations,
# including the capacity check.

# Start clean, so `bin/rails db:seed` can be run again.
Reservation.delete_all
CarCategory.delete_all

today = Date.current
customers = %w[Jana Petr Eva Tomas Lucie Martin Klara Jakub Tereza Ondrej].cycle

book = lambda do |category, from, to|
  name = customers.next
  category.reservations.create!(customer_name: "#{name} Example", customer_email: "#{name.downcase}@example.com",
                                start_date: from, end_date: to)
end

fabia = CarCategory.create!(name: "Skoda Fabia", daily_price: 900, capacity: 10,
                            description: "Small and thrifty hatchback, easy to park in the city.")
octavia = CarCategory.create!(name: "Skoda Octavia Combi", daily_price: 1400, capacity: 3,
                              description: "Roomy estate with a big boot for family trips.")
superb = CarCategory.create!(name: "Skoda Superb", daily_price: 2100, capacity: 2,
                             description: "Comfortable limousine for long journeys and business.")
enyaq = CarCategory.create!(name: "Skoda Enyaq", daily_price: 2400, capacity: 1,
                            description: "Electric SUV with a range of over 500 km.")
CarCategory.create!(name: "Skoda Kamiq", daily_price: 1300, capacity: 4,
                    description: "Compact crossover with a raised seating position.")

# Fabia, 10 cars: nine reservations differ in length but all cover days
# +14 to +16. One more car fits in that period, an eleventh does not.
fabia_busy = today + 14
[ [ -2, 2 ], [ -1, 2 ], [ 0, 2 ], [ 0, 3 ], [ 0, 4 ], [ -3, 2 ], [ 0, 5 ], [ -1, 3 ], [ 0, 2 ] ].each do |from, to|
  book.call(fabia, fabia_busy + from, fabia_busy + to)
end

# Octavia Combi, 3 cars: fully booked from +10 to +12, free the day before and the day after.
3.times { book.call(octavia, today + 10, today + 12) }

# Superb, 2 cars: partial overlaps. Days +21 to +24 are full, the rest has one car free.
book.call(superb, today + 20, today + 22)
book.call(superb, today + 23, today + 25)
book.call(superb, today + 26, today + 29)
book.call(superb, today + 21, today + 24)

# Enyaq, 1 car: a single reservation, free otherwise.
book.call(enyaq, today + 5, today + 8)

# Kamiq, 4 cars: no reservations at all.

puts "Seeded #{CarCategory.count} car categories and #{Reservation.count} reservations."
puts "Fabia almost full:   #{fabia_busy} to #{fabia_busy + 2} (1 of 10 free)"
puts "Octavia Combi full:  #{today + 10} to #{today + 12} (free on #{today + 9} and #{today + 13})"
puts "Superb full:         #{today + 21} to #{today + 24} (one free on #{today + 25} to #{today + 29})"
puts "Enyaq taken:         #{today + 5} to #{today + 8}"
