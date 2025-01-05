defmodule Keila.Contacts.Form.Settings do
  use Ecto.Schema
  import Ecto.Changeset
  import KeilaWeb.Gettext

  @type t :: %__MODULE__{}

  embedded_schema do
    field(:captcha_required, :boolean, default: true)
    field(:double_opt_in_required, :boolean, default: false)
    field(:double_opt_in_subject, :string)
    field(:double_opt_in_markdown_body, :string)
    field(:double_opt_in_message, :string)
    field(:double_opt_in_url, :string)
    field(:csrf_disabled, :boolean, default: true)
    field(:intro_text, :string)
    field(:fine_print, :string)
    field(:body_bg_color, :string, default: "#e5e7eb")
    field(:form_bg_color, :string, default: "#f9fafb")
    field(:text_color, :string, default: "#111827")
    field(:submit_label, :string, default: gettext("Submit"))
    field(:submit_bg_color, :string, default: "#047857")
    field(:submit_text_color, :string, default: "#f9fafb")
    field(:input_bg_color, :string, default: "#ffffff")
    field(:input_border_color, :string, default: "#6b7280")
    field(:input_text_color, :string, default: "#111827")
    field(:success_text, :string)
    field(:success_url, :string)
  end

  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [
      :captcha_required,
      :double_opt_in_required,
      :double_opt_in_subject,
      :double_opt_in_markdown_body,
      :double_opt_in_message,
      :double_opt_in_url,
      :csrf_disabled,
      :intro_text,
      :fine_print,
      :body_bg_color,
      :form_bg_color,
      :text_color,
      :input_text_color,
      :input_bg_color,
      :input_border_color,
      :submit_label,
      :submit_bg_color,
      :submit_text_color,
      :success_text,
      :success_url
    ])
  end
end
