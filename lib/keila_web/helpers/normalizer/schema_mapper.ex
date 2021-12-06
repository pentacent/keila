defmodule KeilaWeb.ApiNormalizer.SchemaMapper do
  @mappings %{
    contact: %{
      "first_name" => "firstName",
      "last_name" => "lastName"
    }
  }

  def to_camel_case(:contact, field) do
    case Map.get(@mappings.contact, to_string(field)) do
      nil -> to_string(field)
      field -> field
    end
  end

  def to_camel_case(%Keila.Contacts.Contact{}, field),
    do: to_camel_case(:contact, field)

  def to_snake_case(:contact, field) do
    @mappings.contact
    |> Enum.find_value(fn {key, value} -> if field == value, do: key end)
    |> case do
      nil -> field
      field -> field
    end
  end

  def to_snake_case(%Keila.Contacts.Contact{}, field), do: to_snake_case(:contact, field)
end
