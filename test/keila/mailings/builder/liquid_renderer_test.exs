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

      assert {:error,
              "Parsing error in line 1:7: Tag or Object not properly terminated (near \"Hello {{ world\")"} =
               render_liquid(input, %{})
    end

    test "returns an error tuple with a useful error message" do
      input = "Hello {{ foo | divided_by: bar }}"
      assigns = %{"foo" => 2, "bar" => 0}
      assert {:error, "Argument error in line 1:16: divided by 0"} = render_liquid(input, assigns)
    end
  end

  describe "process_assigns/1" do
    test "processes assigns to ensure they can be safely used for Liquid template rendering" do
      assigns = %{
        contact: %Keila.Contacts.Contact{email: "test@example.com"},
        tuple: {1, 2},
        map: %{child: %{foo: :bar}}
      }

      assert %{
               "contact" => %{"email" => "test@example.com"},
               "tuple" => [1, 2],
               "map" => %{"child" => %{"foo" => "bar"}}
             } = process_assigns(assigns)
    end
  end
end
