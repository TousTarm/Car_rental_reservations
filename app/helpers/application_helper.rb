module ApplicationHelper
  # Prices are whole crowns, shown Czech style: "12 500 CZK".
  def czk(amount)
    number_to_currency(amount, unit: "CZK", format: "%n %u", precision: 0, delimiter: " ")
  end
end
