defmodule Keila.Repo.Migrations.ConvertMjRawLiquidToKeilaCodeTest do
  use Keila.DataCase, async: false

  # This migration is not included in normal test runs.
  # Run `mix test <this file> --include skip` to execute it.
  @moduletag :skip

  alias Keila.Repo
  alias Keila.Mailings.Campaign

  @migration_file "priv/repo/migrations/20260529100000_convert_mj_raw_liquid_to_keila_code.exs"
  alias Keila.Repo.Migrations.ConvertMjRawLiquidToKeilaCode, as: Migration

  setup_all do
    unless Code.ensure_loaded?(Migration), do: Code.require_file(@migration_file)
    :ok
  end

  setup do
    _root = insert!(:group)
    user = insert!(:user)
    {:ok, project} = Keila.Projects.create_project(user.id, params(:project))
    %{project: project}
  end

  # Run the migration's real conversion SQL on the test's sandbox connection.
  # We can't drive a full Ecto.Migrator pass here: the migrator runs the
  # migration in a separate Task/transaction that can't share the sandbox
  # connection. Executing `update_sql/0` exercises the exact SQL `up/0` runs.
  defp run_migration! do
    # apply/3 (not @migration.update_sql()) because the migration is loaded at
    # runtime, so a direct call would warn about an undefined function at compile.
    Ecto.Adapters.SQL.query!(Repo, apply(Migration, :update_sql, []))
  end

  defp insert_campaign(project, mjml_body) do
    insert!(:mailings_campaign, project_id: project.id, mjml_body: mjml_body)
  end

  defp body_after_migration(project, mjml_body) do
    campaign = insert_campaign(project, mjml_body)
    run_migration!()
    Repo.get!(Campaign, campaign.id).mjml_body
  end

  test "converts a single {% %} tag wrapped in mj-raw", %{project: project} do
    assert body_after_migration(project, ~S(<mj-raw>{% if x %}</mj-raw>)) ==
             ~S(<keila-code>{% if x %}</keila-code>)
  end

  test "leaves a {{ }}-only mj-raw block unchanged (interpolation can't break)", %{
    project: project
  } do
    body = ~S(<mj-raw>{{ user.name }}</mj-raw>)
    assert body_after_migration(project, body) == body
  end

  test "converts each block independently, preserving MJML between them", %{project: project} do
    body = ~S(<mj-raw>{% if a %}</mj-raw><mj-section/><mj-raw>{% endif %}</mj-raw>)

    assert body_after_migration(project, body) ==
             ~S(<keila-code>{% if a %}</keila-code><mj-section/><keila-code>{% endif %}</keila-code>)
  end

  test "leaves mj-raw containing non-liquid markup untouched", %{project: project} do
    body = ~S(<mj-raw>{% if x %}<p>hi</p>{% endif %}</mj-raw>)
    assert body_after_migration(project, body) == body
  end

  test "leaves bodies without mj-raw unchanged", %{project: project} do
    body = ~S(<mjml><mj-body><mj-text>{{ x }}</mj-text></mj-body></mjml>)
    assert body_after_migration(project, body) == body
  end
end
