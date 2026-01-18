defmodule Keila.Mailings.SenderAdapters.Shared.SES do
  use Keila.Mailings.SenderAdapters.Adapter
  use KeilaWeb.Gettext
  alias KeilaWeb.Router.Helpers, as: Routes
  import Ecto.Changeset

  @impl true
  def name, do: "shared_ses"

  @impl true
  def schema_fields do
    [
      # Deprecated:
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
        from_email: email,
        verified_from_email: verified_from_email,
        config: %{},
        shared_sender: shared_sender
      })
      when email == verified_from_email do
    Keila.Mailings.SenderAdapters.SES.to_swoosh_config(shared_sender)
  end

  @impl true
  def put_provider_options(email, %{
        from_email: from_email,
        verified_from_email: verified_from_email,
        shared_sender: shared_sender
      })
      when from_email == verified_from_email do
    Keila.Mailings.SenderAdapters.SES.put_provider_options(email, shared_sender)
  end

  @impl true
  def requires_verification?(), do: true

  @impl true
  def deliver_verification_email(sender, token, _url_fn) do
    email = sender.from_email
    template_name = template_name(sender, email)
    aws_config = aws_config(sender)

    success_url = Routes.sender_url(KeilaWeb.Endpoint, :verify_from_token, token)
    failure_url = Routes.sender_url(KeilaWeb.Endpoint, :cancel_verification_from_token, token)
    subject = gettext("Verify Your Email for Keila")

    content =
      gettext(
        "Please click on the following link to verify your email address %{email} for use with Keila.",
        email: email
      )

    ExAws.SES.delete_custom_verification_email_template(template_name)
    |> ExAws.request(aws_config)

    ExAws.SES.create_custom_verification_email_template(
      template_name,
      system_from_email(),
      subject,
      content,
      success_url,
      failure_url
    )
    |> ExAws.request!(aws_config)

    ExAws.SES.send_custom_verification_email(email, template_name)
    |> ExAws.request!(aws_config)
  end

  @impl true
  def after_from_email_verification(sender) do
    template_name = template_name(sender, sender.from_email)
    aws_config = aws_config(sender)

    ExAws.SES.delete_custom_verification_email_template(template_name)
    |> ExAws.request!(aws_config)

    :ok
  end

  defp template_name(sender, email),
    do: (sender.id <> "_" <> String.replace(email, ~r/[^a-zA-Z]/, "")) |> String.slice(0..63)

  defp aws_config(%{shared_sender: %{config: config}}) do
    [
      region: config.ses_region,
      access_key: config.ses_access_key,
      secret: config.ses_secret
    ]
  end

  defp system_from_email() do
    Application.get_env(:keila, Keila.Auth.Emails) |> Keyword.fetch!(:from_email)
  end
end
