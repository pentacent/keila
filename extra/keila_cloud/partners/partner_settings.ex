require Keila

Keila.if_cloud do
  defmodule KeilaCloud.Partners.PartnerSettings do
    use Ecto.Schema
    import Ecto.Changeset

    @type t :: %__MODULE__{}

    embedded_schema do
      field :credit_allocations, :map, default: %{}
    end

    def changeset(struct \\ %__MODULE__{}, params) do
      struct
      |> cast(params, [:credit_allocations])
      |> validate_credit_allocations()
    end

    defp validate_credit_allocations(changeset) do
      case get_change(changeset, :credit_allocations) do
        nil ->
          changeset

        allocations when is_map(allocations) ->
          if Enum.all?(allocations, fn {k, v} -> is_binary(k) and is_integer(v) and v >= 0 end) do
            changeset
          else
            add_error(
              changeset,
              :credit_allocations,
              "must map account ids to non-negative integers"
            )
          end

        _ ->
          add_error(changeset, :credit_allocations, "must be a map")
      end
    end
  end
end
