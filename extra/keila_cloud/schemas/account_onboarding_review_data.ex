require Keila

Keila.if_cloud do
  defmodule KeilaCloud.Accounts.Account.OnboardingReviewData do
    use Ecto.Schema
    import Ecto.Changeset

    @type t :: %__MODULE__{}

    embedded_schema do
      field :sending_purpose, :string
      field :is_import_planned, :boolean
      field :import_origin, :string
    end

    def changeset(data \\ %__MODULE__{}, params) do
      data
      |> cast(params, [:sending_purpose, :is_import_planned, :import_origin])
      |> validate_required([:sending_purpose, :is_import_planned])
      |> validate_length(:sending_purpose, min: 5)
      |> then(fn changeset ->
        if get_field(changeset, :is_import_planned) do
          changeset
          |> validate_required(:import_origin)
          |> validate_length(:import_origin, min: 5)
        else
          changeset
        end
      end)
    end
  end
end
