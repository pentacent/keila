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
      example: "jane.doe@example.com"
    },
    external_id: %{
      type: :string,
      example: "abc-123"
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

  @id_parameters [
    id: [in: :path, type: :string, description: "Contact ID (or email or external ID)"],
    id_type: [
      in: :query,
      schema: %OpenApiSpex.Schema{type: :string, enum: [:id, :email, :external_id]},
      description:
        "Specify this parameter if you want to use a Contact’s email or external_id to retrieve/update existing Contacts."
    ]
  ]

  def id_parameters() do
    @id_parameters
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

defmodule KeilaWeb.Api.Schemas.Contact.CreateParams do
  use KeilaWeb.Api.Schema

  @properties KeilaWeb.Api.Schemas.Contact.properties()
  @allowed_properties [:email, :external_id, :first_name, :last_name, :data, :status]
  build_open_api_schema(@properties, only: @allowed_properties, required: [:email])
end

defmodule KeilaWeb.Api.Schemas.Contact.UpdateParams do
  use KeilaWeb.Api.Schema

  @properties KeilaWeb.Api.Schemas.Contact.properties()
  @allowed_properties [:email, :external_id, :first_name, :last_name, :data, :status]
  build_open_api_schema(@properties, only: @allowed_properties)
end

defmodule KeilaWeb.Api.Schemas.Contact.DataParams do
  require OpenApiSpex

  %OpenApiSpex.Schema{
    type: :object,
    properties: %{
      data: %OpenApiSpex.Schema{
        type: :object,
        example: %{"tags" => ["rocket-scientist"]}
      }
    }
  }
  |> OpenApiSpex.schema()
end
