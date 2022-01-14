defmodule Keila.Repo.JsonFieldTest do
  use ExUnit.Case, async: true

  @tag :json_field
  test "maps are accepted" do
    types = %{json: Keila.Repo.JsonField}
    params = %{json: %{"foo" => "bar"}}

    assert {:ok, record} =
             {%{}, types}
             |> Ecto.Changeset.cast(params, Map.keys(types))
             |> Ecto.Changeset.apply_action(:insert)

    assert record.json == params.json
  end

  @tag :json_field
  test "JSON object strings are accepted" do
    types = %{json: Keila.Repo.JsonField}
    params = %{json: ~s'{"foo": "bar"}'}

    assert {:ok, record} =
             {%{}, types}
             |> Ecto.Changeset.cast(params, Map.keys(types))
             |> Ecto.Changeset.apply_action(:insert)

    assert record.json == %{"foo" => "bar"}
  end

  @tag :json_field
  test "non-object JSON strings are rejected" do
    types = %{json: Keila.Repo.JsonField}
    params = %{json: ~s'[]'}

    assert {:error, changeset} =
             {%{}, types}
             |> Ecto.Changeset.cast(params, Map.keys(types))
             |> Ecto.Changeset.apply_action(:insert)

    assert [json: {"must be a JSON object", _}] = changeset.errors
  end

  @tag :json_field
  test "invalid JSON is rejected" do
    types = %{json: Keila.Repo.JsonField}
    params = %{json: ~s'{foo: bar}'}

    assert {:error, changeset} =
             {%{}, types}
             |> Ecto.Changeset.cast(params, Map.keys(types))
             |> Ecto.Changeset.apply_action(:insert)

    assert [json: {"unexpected byte at position 1: 0x66 (\"f\")", _}] = changeset.errors
  end

  @tag :json_field
  test "non-map non-binary types are rejected" do
    types = %{json: Keila.Repo.JsonField}
    params = %{json: []}

    assert {:error, changeset} =
             {%{}, types}
             |> Ecto.Changeset.cast(params, Map.keys(types))
             |> Ecto.Changeset.apply_action(:insert)

    assert [json: {"is invalid", _}] = changeset.errors
  end
end
