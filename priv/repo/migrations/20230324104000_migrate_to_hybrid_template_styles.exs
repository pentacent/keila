defmodule Keila.Repo.Migrations.MigrateToHybridTemplateStyles do
  @moduledoc """
  This is a data migration, transforming the styles from the previously used
  DefaultTemplate to be compatible with the new HybridTemplate.

  This migration is not reversible.
  """

  use Ecto.Migration
  import Ecto.Query
  require Ecto.Query
  alias Keila.Repo
  require Logger

  def up do
    Repo.all(from(t in "templates", where: not is_nil(t.styles), select: {t.id, t.styles}))
    |> Enum.filter(fn {_id, styles} ->
      String.contains?(styles, "body, #center-wrapper, #table-wrapper")
    end)
    |> Enum.map(fn {id, styles} ->
      {id,
       styles
       |> String.replace(
         ~r/body, #center-wrapper, #table-wrapper\{([^}]+)\}/U,
         "body{\\1} .email-bg{\\1}"
       )
       |> String.replace("h4>a, div.keila-button", ".block--button .button-td")
       |> String.replace("h4>a, div.keila-button a", ".block--button .button-a")
       |> String.replace("#signature td", "#footer td")
       |> String.replace("#signature td a", "#footer td a")}
    end)
    |> Enum.each(fn {id, updated_styles} ->
      Logger.info("Updating styles for Template #{id}")

      from(t in "templates", where: t.id == ^id, update: [set: [styles: ^updated_styles]])
      |> Repo.update_all([])
    end)
  end

  def down do
    :ok
  end
end
