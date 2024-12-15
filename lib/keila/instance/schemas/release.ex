defmodule Keila.Instance.Release do
  use Keila.Schema

  embedded_schema do
    field :version, :string
    field :published_at, :utc_datetime
    field :changelog, :string
  end

  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:version, :published_at, :changelog])
    |> validate_required([:version, :published_at, :changelog])
    |> validate_change(:version, fn :version, version ->
      case Version.parse(version) do
        {:ok, _} -> []
        _ -> [version: "invalid version format"]
      end
    end)
  end

  def new!(params) do
    params |> changeset() |> Ecto.Changeset.apply_action!(:insert)
  end
end
