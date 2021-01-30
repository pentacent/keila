defmodule Keila.Mailings.Worker do
  use Oban.Worker, queue: :mailer
  use Keila.Repo
  alias Keila.Mailings.{Recipient, Sender}

  @impl true
  def perform(%Oban.Job{args: %{"recipient_id" => recipient_id}}) do
    recipient =
      from(r in Recipient,
        where: r.id == ^recipient_id,
        preload: [contact: [], campaign: :sender]
      )
      |> Repo.one()

    config = Sender.Config.to_swoosh_config(recipient.campaign.sender.config)

    email = Keila.Mailings.Builder.build(recipient.campaign, recipient.contact, %{})
    if Enum.find(email.headers, fn {name, _} -> name == "X-Keila-Invalid" end) do
      raise "INvalid email"
    end

    email
    |> Keila.Mailer.deliver(config)
    |> maybe_update_recipient(recipient)
  end

  defp maybe_update_recipient({:ok, _}, recipient) do
    from(r in Recipient,
      where: r.id == ^recipient.id,
      update: [set: [sent_at: fragment("NOW()")]]
    )
    |> Repo.update_all([])

    :ok
  end
end
