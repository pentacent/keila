require Keila

Keila.if_cloud do
  defmodule KeilaCloud.Accounts.Account.ContactData do
    use Ecto.Schema
    import Ecto.Changeset

    @type t :: %__MODULE__{}

    embedded_schema do
      field :is_organization, :boolean
      field :organization_name

      field :given_name
      field :additional_name
      field :family_name

      field :country, :string
      field :administrative_area
      field :locality
      field :dependent_locality

      field :address_line_1
      field :address_line_2
      field :address_line_3

      field :postal_code
      field :sorting_code

      field :website, :string
      field :phone, :string
    end

    @fields ~w[is_organization organization_name given_name additional_name family_name country administrative_area locality dependent_locality address_line_1 address_line_2 address_line_3 postal_code sorting_code website phone]a

    def changeset(struct \\ %__MODULE__{}, params, required_fields \\ []) do
      struct
      |> cast(params, @fields)
      |> validate_required(required_fields -- [:organization_name])
      |> maybe_validate_required_organization_name(:organization_name in required_fields)
    end

    defp maybe_validate_required_organization_name(changeset, false), do: changeset

    defp maybe_validate_required_organization_name(changeset, true) do
      if get_field(changeset, :is_organization) do
        validate_required(changeset, :organization_name)
      else
        changeset
      end
    end
  end
end
