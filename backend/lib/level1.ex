defmodule Drivy.Level1 do
  use Timex

  def transform path do
    data = JSON.decode!(File.read!(path))
    cars_by_id = get_cars_by_id(data["cars"])

    data["rentals"]
    |> calculate_rental_prices(cars_by_id)
    |> (&([ rentals: &1 ])).() # Add rentals key
    |> JSON.encode!
  end

  def get_cars_by_id cars do
    for car <- cars, into: %{}, do: { car["id"], car }
  end

  def calculate_rental_prices rentals, cars_by_id do
    for rental <- rentals, do: [ id: rental["id"], price: price_from_rental(rental, cars_by_id) ]
  end

  def price_from_rental(rental, cars_by_id) do
    duration_price(rental, cars_by_id) + distance_price(rental, cars_by_id)
  end

  def duration_price rental, cars_by_id do
    rental_duration(rental) * cars_by_id[rental["car_id"]]["price_per_day"]
  end

  def distance_price rental, cars_by_id do
    rental["distance"] * cars_by_id[rental["car_id"]]["price_per_km"]
  end

  def rental_duration rental do
    start_date = DateFormat.parse!(rental["start_date"], "{YYYY}-{0M}-{0D}")
    end_date = DateFormat.parse!(rental["end_date"], "{YYYY}-{0M}-{0D}")
    Date.diff(start_date, end_date, :days) + 1
  end
end
