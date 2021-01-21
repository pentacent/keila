defmodule Keila.Mailings.Worker do
  use Oban.Worker, queue: :mailer
  use Keila.Repo
  alias Swoosh.Email
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

    Email.new()
    |> Email.to(recipient.contact.email)
    |> Email.from(recipient.campaign.sender.from_email)
    |> Email.text_body(recipient.campaign.text_body)
    |> Email.html_body(recipient.campaign.html_body)
    |> Keila.Mailer.deliver(config)
  end
end
