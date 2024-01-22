defmodule Keila.Contacts.EctoStringMapTest do
  use Keila.DataCase, async: true
  alias Ecto.Changeset
  alias Keila.Contacts.EctoStringMap
  alias EctoStringMap.FieldDefinition

  test "casts a map of strings from params" do
    field_definitions = [
      %FieldDefinition{
        key: "someString",
        type: :string
      },
      %FieldDefinition{
        key: "someNumber",
        type: :integer
      },
      %FieldDefinition{
        key: "someBool",
        type: :boolean
      }
    ]

    field_mapping = EctoStringMap.build_field_mapping(field_definitions)

    params = %{
      "data" => %{
        "someString" => "foo",
        "someNumber" => "123",
        "someBool" => "false"
      }
    }

    assert {:ok, contact} =
             %Keila.Contacts.Contact{}
             |> Changeset.cast(params, [])
             |> EctoStringMap.cast_string_map(:data, field_mapping)
             |> EctoStringMap.finalize_string_map(:data)
             |> Changeset.apply_action(:insert)

    assert %{
             "someString" => "foo",
             "someNumber" => 123,
             "someBool" => false
           } == contact.data
  end

  test "applies changesets" do
    field_definitions = [
      %FieldDefinition{
        key: "requiredField",
        type: :string,
        validations: [&Changeset.validate_required(&1, &2, [])]
      }
    ]

    field_mapping = EctoStringMap.build_field_mapping(field_definitions)
    params = %{"data" => %{}}

    assert {:error, _changeset} =
             %Keila.Contacts.Contact{}
             |> Changeset.cast(params, [])
             |> EctoStringMap.cast_string_map(:data, field_mapping)
             |> EctoStringMap.finalize_string_map(:data)
             |> Changeset.apply_action(:insert)
  end
end
