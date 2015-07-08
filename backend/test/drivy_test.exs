defmodule DrivyTest do
  use ExUnit.Case

  test "Level 1" do
    # Get result JSON with whitespace removed
    json = File.read!("level1/output.json") |> String.split |> Enum.join
    assert Drivy.Level1.transform("level1/data.json") == json
  end

  test "Level 2" do
    # Get result JSON with whitespace removed
    json = File.read!("level2/output.json") |> String.split |> Enum.join
    assert Drivy.Level2.transform("level2/data.json") == json
  end
end
