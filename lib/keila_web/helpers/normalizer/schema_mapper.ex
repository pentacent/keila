defmodule KeilaWeb.ApiNormalizer.SchemaMapper do
  @mappings %{
    contact: %{
      "first_name" => "firstName",
      "last_name" => "lastName"
    },
    campaign: %{
      "text_body" => "textBody",
      "html_body" => "htmlBody",
      "sender_id" => "senderId",
      "template_id" => "templateId",
      "segment_id" => "segmentId"
    }
  }

  @struct_mappings %{
    Keila.Contacts.Contact => :contact,
    Keila.Mailings.Campaign => :campaign
  }

  def to_camel_case(type, field) when type in [:contact, :campaign] do
    case Map.get(@mappings[type], to_string(field)) do
      nil -> to_string(field)
      field -> field
    end
  end

  def to_camel_case(%{__struct__: mod}, field),
    do: to_camel_case(@struct_mappings[mod], field)

  def to_snake_case(type, field) when type in [:contact, :campaign] do
    @mappings[type]
    |> Enum.find_value(fn {key, value} -> if field == value, do: key end)
    |> case do
      nil -> field
      field -> field
    end
  end

  def to_snake_case(%{__struct__: mod}, field),
    do: to_snake_case(@struct_mappings[mod], field)
end
