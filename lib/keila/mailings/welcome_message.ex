defmodule Keila.Mailings.WelcomeMessage do
  @moduledoc """
  Module for building and delivering welcome email messages.
  """

  require Keila

  use KeilaWeb.Gettext
  use Keila.Repo

  alias Keila.Contacts
  alias Keila.Contacts.Contact
  alias Keila.Contacts.Form
  alias Keila.Mailings.Message
  alias Keila.Templates.{Css, HybridTemplate}
  alias Swoosh.Email
  alias KeilaWeb.Router.Helpers, as: Routes
  alias KeilaWeb.Endpoint

  @doc """
  Renders a welcome email for the given `contact_id` and `form_id` and inserts a
  Message with `status: :ready` and `priority: 10`.

  Returns `{:ok, message}` on success or `{:error, reason}` on failure.
  """
  def deliver(contact_id, form_id) do
    contact = Contacts.get_contact(contact_id)
    form = Contacts.get_form(form_id)
    sender = Keila.Mailings.get_sender(form.sender_id)
    project_id = form.project_id

    with :ok <- ensure_feature_available(project_id),
         :ok <- ensure_account_active(project_id),
         :ok <- ensure_welcome_enabled(form),
         email <- build(contact, form),
         :ok <- ensure_valid_email(email),
         [{recipient_name, recipient_email}] <- email.to do
      %Message{}
      |> Message.changeset(%{
        status: :ready,
        priority: 10,
        subject: email.subject,
        text_body: email.text_body,
        html_body: email.html_body,
        recipient_email: recipient_email,
        recipient_name: recipient_name,
        project_id: project_id,
        sender_id: sender.id,
        contact_id: contact_id,
        form_id: form_id
      })
      |> Repo.insert()
    end
  end

  @preview_contact %Contact{
    id: "c_id",
    email: "keila@example.com",
    data: %{}
  }

  @preview_assigns %{
    "unsubscribe_link" => "#unsubscribe-preview-link"
  }

  @doc """
  Builds a preview email for the given form.
  """
  @spec preview(Form.t(), Contact.t()) :: Email.t()
  def preview(form, contact \\ @preview_contact) do
    build(contact, form, @preview_assigns)
  end

  @doc """
  Returns the default subject for a welcome email.
  """
  @spec default_subject() :: String.t()
  def default_subject() do
    gettext("Welcome!")
  end

  @doc """
  Returns the default markdown body for a welcome email.
  """
  @spec default_markdown_body() :: String.t()
  def default_markdown_body() do
    gettext("""
    # Welcome!

    Thank you for subscribing to this newsletter.
    """)
  end

  # Building

  defp build(contact, form, assigns \\ %{}) do
    subject = get_subject(form)
    body_markdown = get_body_markdown(form)

    template = if form.template_id, do: Keila.Templates.get_template(form.template_id)
    styles = get_styles(template)

    assigns = build_assigns(assigns, contact, template, subject)

    Email.new()
    |> Email.to(contact.email)
    |> Email.subject(subject)
    |> Keila.Mailings.Builder.Markdown.put_body(body_markdown, styles, assigns)
  end

  defp get_subject(form) do
    case form.settings.welcome_subject do
      empty when empty in [nil, ""] -> default_subject()
      subject -> subject
    end
  end

  defp get_body_markdown(form) do
    case form.settings.welcome_markdown_body do
      empty when empty in [nil, ""] -> default_markdown_body()
      body -> body
    end
  end

  defp get_styles(template) do
    default_styles = HybridTemplate.styles()

    if template && is_binary(template.styles) do
      Css.merge(default_styles, Css.parse!(template.styles))
    else
      default_styles
    end
  end

  defp build_assigns(assigns, contact, template, subject) do
    assigns
    |> Map.put_new_lazy("unsubscribe_link", fn -> get_unsubscribe_link(contact) end)
    |> Map.put("contact", %{
      "email" => contact.email,
      "first_name" => contact.first_name,
      "last_name" => contact.last_name,
      "data" => contact.data || %{}
    })
    |> Map.put("campaign", %{"subject" => subject})
    |> Map.put("styles", get_styles(template))
    |> Map.put("signature", if(template, do: template.assigns["signature"]))
  end

  defp get_unsubscribe_link(contact) do
    # TODO: This uses the deprecated unsigned unsubscribe link.
    # This should be changed once the refactoring for transactional emails will add a record
    # for emails link this welcome email that can be referenced and signed.
    Routes.public_form_url(Endpoint, :unsubscribe, contact.project_id, contact.id)
  end

  # Helpers

  defp ensure_valid_email(email) do
    if Enum.find(email.headers, fn {name, _} -> name == "X-Keila-Invalid" end) do
      {:error, :rendering_error}
    else
      :ok
    end
  end

  defp ensure_welcome_enabled(form) do
    if form.settings.welcome_enabled do
      :ok
    else
      {:error, "Welcome email not enabled for form #{form.id}"}
    end
  end

  Keila.if_cloud do
    defp ensure_feature_available(project_id) do
      if KeilaCloud.Billing.feature_available?(project_id, :welcome_email) do
        :ok
      else
        {:error, "Welcome email not enabled for account of project #{project_id}"}
      end
    end

    defp ensure_account_active(project_id) do
      case Keila.Accounts.get_project_account(project_id) do
        %{status: :active} -> :ok
        _other -> {:error, "Account of project #{project_id} is not active"}
      end
    end
  else
    defp ensure_feature_available(_project_id), do: :ok
    defp ensure_account_active(_project_id), do: :ok
  end
end
