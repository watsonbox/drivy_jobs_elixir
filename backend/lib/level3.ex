defmodule Drivy.Level3 do
  use Timex

  def transform(path) do
    data = JSON.decode!(File.read!(path))
    cars_by_id = get_cars_by_id(data["cars"])

    data["rentals"]
    |> calculate_rental_prices(cars_by_id)
    |> (&([ rentals: &1 ])).() # Add rentals key
    |> JSON.encode!
  end

  def get_cars_by_id(cars) do
    for car <- cars, into: %{}, do: { car["id"], car }
  end

  def calculate_rental_prices(rentals, cars_by_id) do
    for rental <- rentals do
      price = price_from_rental(rental, cars_by_id)

      [
        id: rental["id"],
        price: price,
        commission: calculate_commission(price, rental_duration(rental))
      ]
    end
  end

  def price_from_rental(rental, cars_by_id) do
    duration_price(rental, cars_by_id) + distance_price(rental, cars_by_id)
  end

  def duration_price(rental, cars_by_id) do
    price_per_day = cars_by_id[rental["car_id"]]["price_per_day"]

    rental
    |> rental_duration
    |> discounts
    |> Enum.map(&apply_discount(price_per_day, &1))
    |> Enum.sum
    |> round
  end

  def distance_price(rental, cars_by_id) do
    rental["distance"] * cars_by_id[rental["car_id"]]["price_per_km"]
  end

  def rental_duration(rental) do
    start_date = DateFormat.parse!(rental["start_date"], "{YYYY}-{0M}-{0D}")
    end_date = DateFormat.parse!(rental["end_date"], "{YYYY}-{0M}-{0D}")
    Date.diff(start_date, end_date, :days) + 1
  end

  def apply_discount(price, discount) do
    (1 - discount) * price
  end

  def discounts(days) do
    Enum.map 1..days, &discount/1
  end

  # Define discounts for each day
  def discount(day) when day < 2, do: 0
  def discount(day) when day < 5, do: 0.1
  def discount(day) when day < 11, do: 0.3
  def discount(_), do: 0.5

  def calculate_commission(price, duration) do
    commission = price * 0.3

    [
      insurance_fee: round(commission / 2),
      assistance_fee: duration * 100,
      drivy_fee: round(commission/2 - duration*100)
    ]
  end
end
