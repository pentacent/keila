defmodule Keila.Mailings.Campaign.Settings do
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field(:type, Ecto.Enum, values: [:text, :markdown, :block, :mjml])
    field(:enable_wysiwyg, :boolean, default: true)
    field(:do_not_track, :boolean, default: false)
  end

  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:type, :enable_wysiwyg, :do_not_track])
  end
end
