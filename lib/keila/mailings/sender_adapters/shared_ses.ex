defmodule Keila.Mailings.SenderAdapters.Shared.SES do
  use Keila.Mailings.SenderAdapters.Adapter
  alias KeilaWeb.Router.Helpers, as: Routes
  require KeilaWeb.Gettext
  import Ecto.Changeset

  @impl true
  def name, do: "shared_ses"

  @impl true
  def schema_fields do
    [
      shared_ses_verified_at: :utc_datetime,
      shared_ses_verification_requested_for: :string
    ]
  end

  @impl true
  def changeset(changeset, _params) do
    changeset
    |> change()
    |> put_change(:shared_ses_verified_at, nil)
    |> put_change(:shared_ses_verification_requested_for, nil)
  end

  @impl true
  def to_swoosh_config(%{
        config: %{shared_ses_verified_at: verified_at},
        shared_sender: shared_sender
      })
      when not is_nil(verified_at) do
    Keila.Mailings.SenderAdapters.SES.to_swoosh_config(shared_sender)
  end

  @impl true
  def put_provider_options(email, %{
        config: %{shared_ses_verified_at: verified_at},
        shared_sender: shared_sender
      })
      when not is_nil(verified_at) do
    Keila.Mailings.SenderAdapters.SES.put_provider_options(email, shared_sender)
  end

  # TODO This implementation is less than ideal from an architectural point of
  # view.
  # Eventually, it would be better to find a slightly more general API for
  # sender adapters to generate emails and tokens.
  @impl true
  def after_create(sender) do
    email = sender.from_email

    sender
    |> change(%{
      config:
        change(sender.config, %{
          shared_ses_verified_at: nil,
          shared_ses_verification_requested_for: email
        })
    })
    |> Keila.Repo.update!()

    template_name = template_name(sender, email)
    aws_config = aws_config(sender)
    token_data = %{"email" => email, "type" => "shared_ses", "sender_id" => sender.id}

    {:ok, token} =
      Keila.Auth.create_token(%{user_id: nil, scope: "mailings.verify_sender", data: token_data})

    success_url = Routes.sender_url(KeilaWeb.Endpoint, :verify_from_token, token.key)

    failure_url = Routes.sender_url(KeilaWeb.Endpoint, :cancel_verification_from_token, token.key)

    subject = KeilaWeb.Gettext.gettext("Verify Your Email for Keila")

    content =
      KeilaWeb.Gettext.gettext(
        "Please click on the following link to verify your email address %{email} for use with Keila.",
        email: email
      )

    ExAws.SES.delete_custom_verification_email_template(template_name)
    |> ExAws.request(aws_config)

    ExAws.SES.create_custom_verification_email_template(
      template_name,
      "hello@keila.io",
      subject,
      content,
      success_url,
      failure_url
    )
    |> ExAws.request!(aws_config)

    ExAws.SES.send_custom_verification_email(email, template_name)
    |> ExAws.request!(aws_config)

    :ok
  end

  defp template_name(sender, email),
    do: sender.id <> "_" <> String.replace(email, ~r/[^a-zA-Z]/, "")

  defp aws_config(%{shared_sender: %{config: config}}) do
    [
      region: config.ses_region,
      access_key_id: config.ses_access_key,
      secret_access_key: config.ses_secret
    ]
  end

  @impl true
  def after_update(sender) do
    if sender.from_email == sender.config.shared_ses_verification_requested_for do
      :ok
    else
      after_create(sender)
    end
  end

  @impl true
  def verify_from_token(sender, token) do
    email = token.data["email"]
    config = sender.config

    if sender.from_email == email && config.shared_ses_verification_requested_for == email do
      template_name = template_name(sender, email)
      aws_config = aws_config(sender)

      ExAws.SES.delete_custom_verification_email_template(template_name)
      |> ExAws.request!(aws_config)

      now = DateTime.utc_now() |> DateTime.truncate(:second)

      sender
      |> change(%{config: change(sender.config, %{shared_ses_verified_at: now})})
      |> Keila.Repo.update!()
      |> then(fn sender -> {:ok, sender} end)
    else
      {:error, "verification failed"}
    end
  end

  @impl true
  def cancel_verification_from_token(sender, token) do
    template_name = template_name(sender, token.data["email"])
    aws_config = aws_config(sender)

    ExAws.SES.delete_custom_verification_email_template(template_name)
    |> ExAws.request!(aws_config)

    :ok
  end
end
