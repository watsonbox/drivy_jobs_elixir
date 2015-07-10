defmodule DrivyTest do
  use ExUnit.Case

  test "Level 1" do
    assert_transform Drivy.Level1, "level1/data.json", "level1/output.json"
  end

  test "Level 2" do
    assert_transform Drivy.Level2, "level2/data.json", "level2/output.json"
  end

  test "Level 3" do
    assert_transform Drivy.Level3, "level3/data.json", "level3/output.json"
  end

  defp assert_transform(module, input_path, output_path) do
    # Get result JSON with whitespace removed
    json = File.read!(output_path) |> String.split |> Enum.join
    assert module.transform(input_path) == json
  end
end
