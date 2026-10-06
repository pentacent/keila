defmodule Keila.Repo.Migrations.AddFormEmails do
  @moduledoc """
  Adds the embedded welcome and double opt-in emails to forms.

  The migration also creates email embeds for forms where welcome or double opt-in
  emails were enabled or customized.

  To be cautious, this migration does not delete the old data structures.
  Deleting the deprecated columns should happen in a future migration.
  """

  use Ecto.Migration
  import Ecto.Query
  alias Keila.Repo
  require Logger

  # Only markdown form emails were supported previously.
  @markdown_type 30

  def up do
    alter table("contacts_forms") do
      add :welcome_email, :jsonb
      add :double_opt_in_email, :jsonb
    end

    flush()

    migrate_form_emails()
  end

  def down do
    alter table("contacts_forms") do
      remove :welcome_email
      remove :double_opt_in_email
    end
  end

  defp migrate_form_emails() do
    prefix = repo().config()[:migration_default_prefix] || "public"

    from(f in "contacts_forms",
      prefix: ^prefix,
      select: {f.id, f.template_id, f.settings}
    )
    |> Repo.all()
    |> Enum.each(fn {form_id, template_id, settings} ->
      settings = settings || %{}

      welcome_email =
        build_email(settings, template_id, "welcome", "welcome_enabled")

      double_opt_in_email =
        build_email(settings, template_id, "double_opt_in", "double_opt_in_required")

      if welcome_email || double_opt_in_email do
        from(f in "contacts_forms", prefix: ^prefix, where: f.id == ^form_id)
        |> Repo.update_all(
          set: [welcome_email: welcome_email, double_opt_in_email: double_opt_in_email]
        )

        Logger.info("Migrated emails of form #{form_id}")
      end
    end)
  end

  # Builds an email if it was enabled or customized, otherwise returns nil.
  defp build_email(settings, template_id, name, enabled_key) do
    enabled? = settings[enabled_key] == true
    subject = non_empty_string_or_nil(settings["#{name}_subject"])
    body = non_empty_string_or_nil(settings["#{name}_markdown_body"])
    customized? = subject != nil or body != nil or template_id != nil

    if enabled? or customized? do
      %{
        "id" => Ecto.UUID.generate(),
        "type" => @markdown_type,
        "subject" => subject,
        "text_body" => body,
        "template_id" => template_id,
        "editor_config" => %{"enable_wysiwyg" => false}
      }
    end
  end

  defp non_empty_string_or_nil(value) when is_binary(value) do
    if String.trim(value) == "", do: nil, else: value
  end

  defp non_empty_string_or_nil(_value), do: nil
end
