defmodule Drivy.Level4 do
  use Timex

  def transform(path) do
    data = JSON.decode!(File.read!(path))

    data["rentals"]
    |> rentals_with_cars(data["cars"])
    |> rentals_with_durations
    |> rentals_with_prices
    |> rental_pricing_data
    |> JSON.encode!
  end

  def get_cars_by_id(cars) do
    for car <- cars, into: %{}, do: { car["id"], car }
  end

  def rentals_with_cars(rentals, cars) do
    cars_by_id = get_cars_by_id(cars)
    for rental <- rentals, do: Map.put(rental, :car, cars_by_id[rental["car_id"]])
  end

  def rentals_with_durations(rentals) do
    for rental <- rentals, do: Map.put(rental, :duration, rental_duration(rental))
  end

  def rentals_with_prices(rentals) do
    for rental <- rentals, do: Map.put(rental, :price, rental_price(rental))
  end

  def rental_pricing_data(rentals) do
    [
      rentals: for rental <- rentals do
        [
          id: rental["id"],
          price: rental.price,
          options: [deductible_reduction: rental_deductible_reduction(rental)],
          commission: rental_commission(rental)
        ]
      end
    ]
  end

  def rental_price(rental) do
    duration_price(rental) + distance_price(rental)
  end

  def duration_price(rental) do
    price_per_day = rental.car["price_per_day"]

    rental
    |> rental_duration
    |> discounts
    |> Enum.map(&apply_discount(price_per_day, &1))
    |> Enum.sum
    |> round
  end

  def distance_price(rental) do
    rental["distance"] * rental.car["price_per_km"]
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

  def rental_commission(rental) do
    commission = rental.price * 0.3

    [
      insurance_fee: round(commission / 2),
      assistance_fee: rental.duration * 100,
      drivy_fee: round(commission/2 - rental.duration*100)
    ]
  end

  def rental_deductible_reduction(%{"deductible_reduction" => false}), do: 0
  def rental_deductible_reduction(rental) do
    rental.duration * 400
  end
end
