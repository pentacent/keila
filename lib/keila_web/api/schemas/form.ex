defmodule KeilaWeb.Api.Schemas.Form do
  use KeilaWeb.Api.Schema

  @properties %{
    id: %{
      type: :string,
      description: "Form ID",
      example: "frm_12345"
    },
    name: %{
      type: :string,
      example: "My Form"
    },
    sender_id: %{
      type: :string,
      example: "ms_12345"
    },
    template_id: %{
      type: :string,
      example: "tpl_12345"
    },
    settings: %{
      type: :map,
      properties: %{
        captcha_required: %{type: :boolean},
        double_opt_in_required: %{type: :boolean},
        double_opt_in_subject: %{type: :string},
        double_opt_in_markdown_body: %{type: :string},
        double_opt_in_message: %{type: :string},
        double_opt_in_url: %{
          type: :string,
          description: "URL to redirect after a form was submitted and double opt-in is required."
        },
        csrf_disabled: %{type: :boolean},
        intro_text: %{type: :string},
        fine_print: %{type: :string},
        body_bg_color: %{type: :string},
        form_bg_color: %{type: :string},
        text_color: %{type: :string},
        submit_label: %{type: :string},
        submit_bg_color: %{type: :string},
        submit_text_color: %{type: :string},
        input_bg_color: %{type: :string},
        input_border_color: %{type: :string},
        input_text_color: %{type: :string},
        success_text: %{type: :string},
        success_url: %{
          type: :string,
          description:
            "URL to redirect after contact was successfully created - either after double opt-in or after form submission without double opt-in. Supports Liquid with the `contact` assign present.",
          example: "https://example.com/thank-you/{{ contact.id }}"
        },
        failure_text: %{type: :string},
        failure_url: %{type: :string}
      }
    },
    fields: %{
      type: :array,
      items: %{
        field: %{
          type: :string,
          enum: [:email, :first_name, :last_name, :data]
        },
        required: %{
          type: :boolean
        },
        cast: %{
          type: :boolean
        },
        key: %{
          type: :string
        },
        type: %{
          type: :string,
          values: [:email, :string, :integer, :boolean, :enum, :tags, :array]
        },
        label: %{
          type: :string
        },
        placeholder: %{
          type: :string
        },
        description: %{
          type: :string
        },
        allowed_values: %{
          type: :array,
          items: %{label: %{type: :string}, value: %{type: :string}}
        }
      }
    }
  }

  def properties() do
    @properties
  end
end

defmodule KeilaWeb.Api.Schemas.Form.Response do
  use KeilaWeb.Api.Schema

  @properties KeilaWeb.Api.Schemas.Form.properties()
  build_open_api_schema(@properties)
end

defmodule KeilaWeb.Api.Schemas.Form.IndexResponse do
  use KeilaWeb.Api.Schema

  @properties KeilaWeb.Api.Schemas.Form.properties()
  build_open_api_schema(@properties, list: true, with_pagination: true)
end

defmodule KeilaWeb.Api.Schemas.Form.DoubleOptInResponse do
  use KeilaWeb.Api.Schema

  build_open_api_schema(%{double_opt_in_required: %{type: :boolean, enum: [true]}})
end

defmodule KeilaWeb.Api.Schemas.Form.CreateParams do
  use KeilaWeb.Api.Schema

  @properties KeilaWeb.Api.Schemas.Form.properties()
  @allowed_properties [:name, :sender_id, :template_id, :settings, :fields]
  build_open_api_schema(@properties, only: @allowed_properties, required: [:name])
end

defmodule KeilaWeb.Api.Schemas.Form.UpdateParams do
  use KeilaWeb.Api.Schema

  @properties KeilaWeb.Api.Schemas.Form.properties()
  @allowed_properties [:name, :sender_id, :template_id, :settings, :fields]
  build_open_api_schema(@properties, only: @allowed_properties)
end

defmodule KeilaWeb.Api.Schemas.Form.DataParams do
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
