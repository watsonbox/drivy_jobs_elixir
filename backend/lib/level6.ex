defmodule Drivy.Level6 do
  use Timex

  @date_format "{YYYY}-{0M}-{0D}"

  def transform(path) do
    data = path |> File.read! |> JSON.decode!

    rentals = data["rentals"]
    |> add_by_id(:car, data["cars"]) # Add cars to rental data
    |> add_rentals_prices

    data["rental_modifications"]
    |> add_by_id(:rental, rentals) # Add rentals to rental modification data
    |> rental_mods_data
    |> JSON.encode!
  end

  def add_by_id(target_collection, field, source_collection) do
    collection_by_id = source_collection |> index_by("id")

    for x <- target_collection do
      Map.put(x, field, collection_by_id[x[Atom.to_string(field) <> "_id"]])
    end
  end

  def add_rentals_prices(rentals) do
    Enum.map rentals, &add_rental_price/1
  end

  def add_rental_price(rental) do
    rental
    |> Map.put(:duration, rental_duration(rental))
    |> (fn(r) -> Map.put(r, :price, rental_price(r)) end).()
  end

  def add_rental_mods_rentals(rental_mods, rentals) do
    rentals_by_id = rentals |> index_by("id")
    for rm <- rental_mods, do: Map.put(rm, :rental, rentals_by_id[rm["rental_id"]])
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
    actions_after_mod = rental_mod
    |> Map.take(["distance", "start_date", "end_date"])
    |> Map.to_list
    |> apply_rental_mods(rental)
    |> rental_actions

    diff_rental_actions(actions_after_mod, rental_mod.rental |> rental_actions)
  end

  # Internal representation of actions for a given rental
  def rental_actions(rental) do
    commission = rental_commission(rental)

    [
      driver: -(rental.price + rental_deductible_reduction(rental)),
      owner: rental.price - (commission |> Map.values |> Enum.sum),
      insurance: commission.insurance_fee,
      assistance: commission.assistance_fee,
      drivy: commission.drivy_fee + rental_deductible_reduction(rental)
    ]
    |> transform_values(&round/1) # Round values
  end

  def diff_rental_actions(action1, action2) do
    for { actor, amount } <- action1, into: [], do: { actor, amount - action2[actor] }
  end

  def apply_rental_mods([], rental), do: add_rental_price(rental)
  def apply_rental_mods([{k, v} | rest], rental) do
    rest |> apply_rental_mods(Map.put(rental, k, v))
  end

  def rental_price(rental) do
    duration_price(rental) + distance_price(rental)
  end

  def duration_price(rental) do
    rental.duration
    |> discounts
    |> Enum.map(&apply_discount(rental.car["price_per_day"], &1))
    |> Enum.sum
    |> round
  end

  def distance_price(rental) do
    rental["distance"] * rental.car["price_per_km"]
  end

  def rental_duration(rental) do
    start_date = rental["start_date"] |> DateFormat.parse!(@date_format)
    end_date = rental["end_date"] |> DateFormat.parse!(@date_format)
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

    %{
      insurance_fee: round(commission / 2),
      assistance_fee: rental.duration * 100,
      drivy_fee: round(commission/2 - rental.duration*100)
    }
  end

  def rental_deductible_reduction(%{"deductible_reduction" => false}), do: 0
  def rental_deductible_reduction(rental), do: rental.duration * 400

  defp transform_values(dict, transform) do
    for { k, v } <- dict, into: [], do: { k, transform.(v) }
  end

  defp index_by(list, field) do
    for x <- list, into: %{}, do: { x[field], x }
  end
end
