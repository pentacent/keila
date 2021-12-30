defmodule KeilaWeb.Api.Schemas.ContactsSegment do
  use KeilaWeb.Api.Schema

  @properties %{
    id: %{
      type: :string,
      description: "Contact ID",
      example: "c_12345"
    },
    name: %{
      type: :string,
      description: "Segment name",
      example: "Rocket scientists and book enthusiasts"
    },
    filter: %{
      type: :map,
      description: "Filter JSON",
      example: %{"email" => %{"$like" => "%keila.io"}}
    },
    inserted_at: %{
      type: :string,
      format: :utc_datetime,
      example: DateTime.utc_now() |> DateTime.to_iso8601()
    },
    updated_at: %{
      type: :string,
      format: :utc_datetime,
      example: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  }

  def properties() do
    @properties
  end
end

defmodule KeilaWeb.Api.Schemas.ContactsSegment.Response do
  use KeilaWeb.Api.Schema

  @properties KeilaWeb.Api.Schemas.ContactsSegment.properties()
  build_open_api_schema(@properties)
end

defmodule KeilaWeb.Api.Schemas.ContactsSegment.IndexResponse do
  use KeilaWeb.Api.Schema

  @properties KeilaWeb.Api.Schemas.ContactsSegment.properties()
  build_open_api_schema(@properties, list: true, with_pagination: true)
end

defmodule KeilaWeb.Api.Schemas.ContactsSegment.Params do
  use KeilaWeb.Api.Schema

  @properties KeilaWeb.Api.Schemas.ContactsSegment.properties()
  @allowed_properties [:name, :filter]
  build_open_api_schema(@properties, only: @allowed_properties)
end
