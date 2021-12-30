defmodule KeilaWeb.Api.Schemas.Contact do
  use KeilaWeb.Api.Schema

  @properties %{
    id: %{
      type: :string,
      description: "Contact ID",
      example: "c_12345"
    },
    email: %{
      type: :string,
      format: :email,
      required: true,
      example: "jane.doe@example.com"
    },
    first_name: %{
      type: :string,
      example: "Jane"
    },
    last_name: %{
      type: :string,
      example: "Doe"
    },
    status: %{
      type: :string,
      enum: ["active", "unsubscribed", "unreachable"],
      example: "active"
    },
    data: %{
      type: :map,
      example: %{"tags" => ["rocket-scientist"]}
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

defmodule KeilaWeb.Api.Schemas.Contact.Response do
  use KeilaWeb.Api.Schema

  @properties KeilaWeb.Api.Schemas.Contact.properties()
  build_open_api_schema(@properties)
end

defmodule KeilaWeb.Api.Schemas.Contact.IndexResponse do
  use KeilaWeb.Api.Schema

  @properties KeilaWeb.Api.Schemas.Contact.properties()
  build_open_api_schema(@properties, list: true, with_pagination: true)
end

defmodule KeilaWeb.Api.Schemas.Contact.Params do
  use KeilaWeb.Api.Schema

  @properties KeilaWeb.Api.Schemas.Contact.properties()
  @allowed_properties [:email, :first_name, :last_name, :data]
  build_open_api_schema(@properties, only: @allowed_properties)
end
