defmodule Keila.Contacts.EctoStringMap do
  @moduledoc """
  Module for casting data and validating map fields with dynamic fields and
  string within an Ecto Schema.

  ## Why use this module?
  This module is a workaround for a limitation in Ecto that doesn’t allow the
  use of string keys. When accepting field definitions from end users, string
  keys are desirable because atoms are never garbage-collected on the BEAM.

  ## Usage
  The way this module works around Ecto not supporting string keys is by
  creating a changeset with generic atom keys (i. e. `:field_1`, `:field_2`, etc)
  and the dynamic string keys.

  This mapping can be generated from a list of `FieldDefinition`s.
  `FieldDefinition`s include a `key` (the string key), and
  `type` (that corresponds to an Ecto) type.
  Optionally, `validations` can be specified as functions that take the
  ad-hoc changeset and the mapped atom key:

    field_mapping = build_field_mapping([
      %FieldDefinition{
        key: "MyStringKey",
        type: :string,
        validations: [&Ecto.Changeset.validate_required(&1, &2, [])]
      }
    ])

  Using this mapping, `cast_string_map` can used with a changeset similarly
  to Ecto’s `cast_embed`:

  changeset = %MySchema{}
  |> cast(%{"map_field" => %{"MyStringKey" => "hello"}})
  |> EctoStringMap.cast_string_map(:data, field_mapping)


  ## Limitations
  Before persisting a changeset with a StringMap field or before using it in a
  Phoenix form to show error feedback, `finalize_string_map/3` must be called.
  This function is similar to Ecto’s `apply_changes` and transform the StringMap
  changeset into the final map form if it's valid. Else, it adds the `action` to
  the field changeset:

    changeset
    |> finalize_string_map(:map_field)
    |> apply_action!(:insert)

    # => %MySchema{
      map_field: %{"MyStringKey" => "hello"}
    }
  """

  import Ecto.Changeset

  @max_allowed_fields 32
  @type field_mapping :: [{atom(), __MODULE__.FieldDefinition.t()}]

  @doc """
  Builds a field mapping from a list of `FieldDefinition`s.
  """
  @spec build_field_mapping([__MODULE__.FieldDefinition.t()]) :: field_mapping
  def build_field_mapping(definitions) do
    definitions
    |> Enum.take(@max_allowed_fields)
    |> Enum.with_index()
    |> Enum.map(fn {definition, n} ->
      {:"field_#{n}", definition}
    end)
  end

  @doc """
  Casts a string map from parameters that have been cast using
  `Ecto.Changeset.cast/4` before.
  """
  def cast_string_map(changeset, field, field_mapping) do
    params = get_params(changeset, field, field_mapping)
    types = field_mapping_to_types(field_mapping)
    atom_keys = Map.keys(types)

    string_map_changeset =
      {%{}, types}
      |> cast(params, atom_keys)
      |> apply_validations(field_mapping)
      |> Map.put_new(:__string_map_field_mapping__, field_mapping)

    changeset
    |> put_change(field, string_map_changeset)
  end

  @doc """
  Applies an `action` to a StringMap field. If the StringMap field is valid,
  the changeset is converted into the final string map form, if it’s invalid,
  applies the given `action` to the error changeset.
  """
  def finalize_string_map(changeset, field, action \\ :insert) do
    string_map_changeset = get_change(changeset, field)
    do_finalize_string_map(changeset, field, string_map_changeset, action)
  end

  defp do_finalize_string_map(
         changeset = %{valid?: true},
         field,
         string_map_changeset = %{valid?: true},
         _
       ) do
    field_content = changeset_to_map(string_map_changeset)
    put_change(changeset, field, field_content)
  end

  defp do_finalize_string_map(
         changeset,
         field,
         string_map_changeset,
         action
       ) do
    string_map_changeset = %{string_map_changeset | action: action}

    changeset
    |> put_change(field, string_map_changeset)
    |> then(fn changeset ->
      if string_map_changeset.valid?,
        do: changeset,
        else: add_error(changeset, field, "invalid string map")
    end)
  end

  defp get_params(%{params: params}, field, field_mapping) when is_map(params) do
    (params[field] || params[to_string(field)] || %{})
    |> Enum.map(&to_atom_param(&1, field_mapping))
    |> Enum.reject(&is_nil/1)
    |> Enum.into(%{})
  end

  defp get_params(_, _, _), do: %{}

  defp to_atom_param({string_key, value}, field_mapping) do
    Enum.find_value(field_mapping, fn {atom_key, definition} ->
      if definition.key == string_key, do: {atom_key, value}
    end)
  end

  defp field_mapping_to_types(field_mapping) do
    Enum.map(field_mapping, fn {atom_key, %{type: type}} ->
      type =
        case type do
          :tags -> {:array, :string}
          :enum -> :string
          type -> type
        end

      {atom_key, type}
    end)
    |> Enum.into(%{})
  end

  defp apply_validations(changeset, field_mapping) do
    Enum.reduce(field_mapping, changeset, fn {atom_key, %{validations: validations}}, changeset ->
      validations = validations || []

      Enum.reduce(validations, changeset, fn validation, changeset ->
        validation.(changeset, atom_key)
      end)
    end)
  end

  defp changeset_to_map(string_map_changeset) do
    field_mapping = string_map_changeset.__string_map_field_mapping__

    string_map_changeset.changes
    |> Enum.map(fn {atom_key, value} ->
      string_key =
        Enum.find_value(field_mapping, fn
          {^atom_key, %{key: string_key}} -> string_key
          _ -> nil
        end)

      {string_key, value}
    end)
    |> Enum.into(%{})
  end
end

defmodule Keila.Contacts.EctoStringMap.FieldDefinition do
  @type t :: %__MODULE__{}
  defstruct [:key, :type, :validations]
  import Ecto.Changeset

  @doc """
  Creates a FieldDefinition struct from a Keila FieldSettings struct.
  """
  def from_field_settings(field_settings) do
    validations = type_validations(field_settings) ++ required_validations(field_settings)

    %__MODULE__{
      key: field_settings.key,
      type: field_settings.type,
      validations: validations
    }
  end

  defp type_validations(%{type: :email}) do
    [&validate_email(&1, &2)]
  end

  defp type_validations(%{type: :enum, allowed_values: allowed_values}) do
    allowed_values = Enum.map(allowed_values, & &1.value)
    [&validate_inclusion(&1, &2, allowed_values)]
  end

  defp type_validations(_), do: []

  defp required_validations(%{type: :boolean, required: true}),
    do: [&validate_acceptance(&1, &2, [])]

  defp required_validations(%{required: true}),
    do: [&validate_required(&1, &2, [])]

  defp required_validations(_), do: []

  @email_regex ~r/^[^\s@]+@[^\s@]+$/
  defp validate_email(changeset, field) do
    changeset
    |> validate_format(field, @email_regex, message: "must have the @ sign and no spaces")
    |> validate_length(field, max: 255)
  end
end
