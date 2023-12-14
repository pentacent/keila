defmodule Keila.Mailings.Builder.LiquidRendererTest do
  use Keila.DataCase, async: true

  import Keila.Mailings.Builder.LiquidRenderer

  describe "render_liquid/3" do
    test "renders a liquid template from a string" do
      input = "Hello {{ world }}!"
      assigns = %{"world" => "World"}
      assert {:ok, "Hello World!"} = render_liquid(input, assigns)
    end

    test "renders a liquid template from a pre-rendered Solid template" do
      input = "Hello {{ world }}!" |> Solid.parse!()
      assigns = %{"world" => "World"}
      assert {:ok, "Hello World!"} = render_liquid(input, assigns)
    end

    test "returns an error tuple from an invalid Liquid template" do
      input = "Hello {{ world"

      assert {:error, "Parsing error in line 1: expected end of string"} =
               render_liquid(input, %{})
    end

    test "returns an error tuple when there is a Liquid rendering error" do
      input = "Hello {{ foo | abs }}"
      assigns = %{"foo" => "bar"}
      assert {:error, "Unexpected rendering error"} = render_liquid(input, assigns)
    end
  end
end
