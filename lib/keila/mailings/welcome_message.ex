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
  alias Keila.Mailings.Renderer

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
         :ok <- ensure_sender(sender) do
      insert_and_render(contact, form, sender)
    end
  end

  # Insert an unrendered message first to retrieve the message id.
  defp insert_and_render(contact, form, sender) do
    Repo.transaction(fn ->
      with {:ok, message} <- insert_unrendered_message(contact, form, sender),
           unsubscribe_link = Keila.Mailings.get_unsubscribe_link(form.project_id, message.id),
           %{valid?: true} = output <- render(contact, form, unsubscribe_link),
           {:ok, message} <- finalize_message(message, output) do
        message
      else
        %{valid?: false} -> Repo.rollback(:rendering_error)
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp insert_unrendered_message(contact, form, sender) do
    %Message{}
    |> Message.changeset(%{
      status: :unrendered,
      priority: 10,
      subject: "",
      recipient_email: contact.email,
      recipient_name: Contacts.display_name(contact),
      project_id: form.project_id,
      sender_id: sender.id,
      contact_id: contact.id,
      form_id: form.id
    })
    |> Repo.insert()
  end

  defp finalize_message(message, output) do
    message
    |> Message.changeset(%{
      status: :ready,
      subject: output.subject,
      text_body: output.text_body,
      html_body: output.html_body
    })
    |> Repo.update()
  end

  @preview_contact %Contact{
    id: "c_id",
    email: "keila@example.com",
    data: %{}
  }

  @doc """
  Builds a preview of the rendered welcome email for the given form.
  """
  @spec preview(Form.t(), Contact.t()) :: Renderer.Output.t()
  def preview(form, contact \\ @preview_contact) do
    render(contact, form, "#unsubscribe-preview-link")
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

  defp render(contact, form, unsubscribe_link, assigns \\ %{}) do
    subject = get_subject(form)
    body_markdown = get_body_markdown(form)
    template = if form.template_id, do: Keila.Templates.get_template(form.template_id)

    input = %Renderer.Input{
      type: :markdown,
      subject: subject,
      text_body: body_markdown,
      template: template,
      assigns:
        build_assigns(assigns, contact, template, subject)
        |> Map.put("unsubscribe_link", unsubscribe_link)
    }

    Renderer.render(input)
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

  defp build_assigns(assigns, contact, template, subject) do
    assigns
    |> Map.put("contact", %{
      "email" => contact.email,
      "first_name" => contact.first_name,
      "last_name" => contact.last_name,
      "data" => contact.data || %{}
    })
    |> Map.put("campaign", %{"subject" => subject})
    |> Map.put("signature", if(template, do: template.assigns["signature"]))
  end

  # Helpers

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

  defp ensure_sender(%Keila.Mailings.Sender{}), do: :ok
  defp ensure_sender(_), do: {:error, :no_sender}
end
