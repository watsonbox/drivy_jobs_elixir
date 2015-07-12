defmodule Drivy.Level6 do
  use Timex

  def transform(path) do
    data = JSON.decode!(File.read!(path))

    rentals = data["rentals"]
    |> rentals_with_cars(data["cars"])
    |> rentals_with_durations
    |> rentals_with_prices

    data["rental_modifications"]
    |> rental_mods_with_rentals(rentals)
    |> rental_mods_data
    |> JSON.encode!
  end

  def rentals_with_cars(rentals, cars) do
    cars_by_id = index_by_id(cars)
    for rental <- rentals, do: Map.put(rental, :car, cars_by_id[rental["car_id"]])
  end

  def rentals_with_durations(rentals) do
    for rental <- rentals, do: Map.put(rental, :duration, rental_duration(rental))
  end

  def rentals_with_prices(rentals) do
    for rental <- rentals, do: Map.put(rental, :price, rental_price(rental))
  end

  def rental_mods_with_rentals(rental_mods, rentals) do
    rentals_by_id = index_by_id(rentals)
    for rental_mod <- rental_mods, do: Map.put(rental_mod, :rental, rentals_by_id[rental_mod["rental_id"]])
  end

  # Presenter for rental modifications
  def rental_mods_data(rental_mods) do
    [
      rental_modifications: for rental_mod <- rental_mods do
        actions = for { actor, amount } <- rental_actions(rental_mod), do: [
          who: actor,
          type: (if amount < 0, do: "debit", else: "credit"),
          amount: abs(amount)
        ]

        [id: rental_mod["id"], rental_id: rental_mod.rental["id"], actions: actions]
      end
    ]
  end

  # Actions for a modification are the difference between those for the rental pre and post modification
  def rental_actions(rental_mod = %{rental: rental}) do
    diff_rental_actions(
      rental_mod
        |> Map.take(["distance", "start_date", "end_date"])
        |> Map.to_list
        |> apply_rental_mods(rental)
        |> rental_actions,
      rental_mod.rental
        |> rental_actions
    )
  end

  # Internal representation of actions for a given rental
  def rental_actions(rental) do
    commission = rental_commission(rental)

    [
      driver: -(rental.price + rental_deductible_reduction(rental)),
      owner: rental.price - rental_commission_total(rental),
      insurance: commission.insurance_fee,
      assistance: commission.assistance_fee,
      drivy: commission.drivy_fee + rental_deductible_reduction(rental)
    ]
    |> transform_values(&round/1) # Round values
  end

  def diff_rental_actions(action1, action2) do
    for { actor, amount } <- action1, into: [], do: { actor, amount - action2[actor] }
  end

  def apply_rental_mods([{k, v} | rest], rental) do
    rest |> apply_rental_mods(Map.put(rental, k, v))
  end

  def apply_rental_mods([], rental) do
    rental
    |> Map.put(:duration, rental_duration(rental))
    |> Map.put(:price, rental_price(rental))
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
    commission = rental_commission_total(rental)

    %{
      insurance_fee: round(commission / 2),
      assistance_fee: rental.duration * 100,
      drivy_fee: round(commission/2 - rental.duration*100)
    }
  end

  def rental_commission_total(rental) do
    rental.price * 0.3
  end

  def rental_deductible_reduction(%{"deductible_reduction" => false}), do: 0
  def rental_deductible_reduction(rental) do
    rental.duration * 400
  end

  defp transform_values(dict, transform) do
    for { k, v } <- dict, into: [], do: { k, transform.(v) }
  end

  defp index_by_id(array) do
    for x <- array, into: %{}, do: { x["id"], x }
  end
end
