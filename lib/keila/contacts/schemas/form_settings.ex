defmodule Keila.Contacts.Form.Settings do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  embedded_schema do
    field(:captcha_required, :boolean)
    field(:top_text)
    field(:fine_print)
    field(:body_bg_color, :string)
    field(:form_bg_color, :string)
    field(:text_color, :string)
    field(:submit_label, :string)
    field(:submit_bg_color, :string)
    field(:submit_text_color, :string)
  end

  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [
      :captcha_required,
      :top_text,
      :fine_print,
      :body_bg_color,
      :form_bg_color,
      :text_color,
      :submit_label,
      :submit_bg_color,
      :submit_text_color
    ])
  end
end
