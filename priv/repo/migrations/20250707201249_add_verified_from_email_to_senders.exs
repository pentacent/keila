defmodule Keila.Repo.Migrations.AddVerifiedFromEmailToSenders do
  use Ecto.Migration

  def up do
    alter table("mailings_senders") do
      add :verified_from_email, :string
    end

    # Data migration to set verified_from_email based on sender type
    execute """
    UPDATE mailings_senders
    SET verified_from_email = CASE
      WHEN config->>'type' = 'shared_ses' AND config->>'shared_ses_verified_at' IS NOT NULL THEN config->>'shared_ses_verification_requested_for'
      ELSE from_email
    END
    """
  end

  def down do
    alter table("mailings_senders") do
      remove :verified_from_email
    end
  end
end
