defmodule Keila.Repo.Migrations.ConvertMjRawLiquidToKeilaCode do
  use Ecto.Migration

  # Previously, MJML campaigns wrapped Liquid tags inside <mj-body> in
  # <mj-raw>...</mj-raw>. After the template refactor, Liquid is processed
  # first which can break the template by leaving stray opening/closing mj-raw
  # tags. So technically, no new wrapper is necessary but <keila-code> was added
  # so that the future WYSIWYG editor has an element to work with.
  #
  # This migration converts <mj-raw> tags that contain only {% %} statements into <keila-code>.
  @update_sql ~S"""
  UPDATE mailings_campaigns
  SET mjml_body = regexp_replace(
    mjml_body,
    '<mj-raw[^>]*>((?:\s*\{%(?:(?!%\}).)*%\}\s*)+)</mj-raw>',
    '<keila-code>\1</keila-code>',
    'g'
  )
  WHERE mjml_body LIKE '%<mj-raw%'
  """

  def update_sql, do: @update_sql

  def up do
    execute(@update_sql)
  end

  def down do
    :ok
  end
end
