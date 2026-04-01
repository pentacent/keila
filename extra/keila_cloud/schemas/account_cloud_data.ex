require Keila

Keila.if_cloud do
  defmodule KeilaCloud.Accounts.Account.CloudData do
    use Ecto.Schema
    import Ecto.Changeset

    @type t :: %__MODULE__{}

    embedded_schema do
      field :ref, :string
      field :utm_source, :string
      field :utm_campaign, :string
      field :self_reported_source, :string
    end

    @fields ~w[ref utm_source utm_campaign self_reported_source]a

    def changeset(struct \\ %__MODULE__{}, params) do
      struct
      |> cast(params, @fields)
      |> validate_length(:ref, max: 100)
      |> validate_length(:utm_source, max: 100)
      |> validate_length(:utm_campaign, max: 100)
      |> validate_length(:self_reported_source, max: 500)
    end
  end
end
