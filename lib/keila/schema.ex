defmodule Keila.Schema do
  @moduledoc """
  Convenience module for use in all schemas.

  `use Keila.Schema` inserts the following code:
      alias Ecto.Repo
      require Ecto.Query
      import Ecto.Query
      import Ecto.Changeset
      use Ecto.Schema
      use Keila.Id, unquote(opts)

      @type t :: %__MODULE__{}

  Options given are passed to `Keila.Id`.

  This module also makes the changeset function `validate_assoc_project/3`
  available. This function uses `prepare_changes/2` to ensure the `project_id`
  of an association is the same as that of the changeset.
  Usage: `validate_assoc_project(changeset, :contact, Keila.Contacts.Contact`
  """
  defmacro __using__(opts) do
    quote do
      alias Ecto.Repo
      require Ecto.Query
      import Ecto.Query
      import Ecto.Changeset
      use Ecto.Schema
      use Keila.Id, unquote(opts)
      @timestamps_opts [type: :utc_datetime]

      @type t :: %__MODULE__{}

      defp validate_assoc_project(changeset, assoc, assoc_schema) do
        prepare_changes(changeset, fn changeset ->
          field = :"#{assoc}_id"

          if assoc_id = get_change(changeset, field) do
            project_id = get_field(changeset, :project_id)

            valid_assoc? =
              from(a in assoc_schema, where: a.id == ^assoc_id and a.project_id == ^project_id)
              |> changeset.repo.exists?()

            if valid_assoc? do
              changeset
            else
              changeset |> add_error(:"#{assoc}_id", "association not found")
            end
          else
            changeset
          end
        end)
      end
    end
  end
end
