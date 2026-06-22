defmodule Keila.Mailings.TransactionalMessage do
  @moduledoc """
  Builds and delivers one-off transactional email messages.
  """

  require Keila
  use Keila.Repo

  alias Keila.Contacts
  alias Keila.Contacts.Contact
  alias Keila.Mailings
  alias Keila.Mailings.{Message, Sender, Renderer}
  alias Keila.Mailings.TransactionalMessage.Request
  alias Keila.Projects.Project
  alias Keila.Templates
  alias Keila.Templates.Template

  @type error ::
          Ecto.Changeset.t()
          | :sender_not_found
          | :template_not_found
          | :contact_not_found
          | :no_subject
          | :account_not_active
          | :insufficient_credits
          | {:rendering_failed, term()}

  @doc """
  Casts and validates a `TransactionalMessage.Request`, renders
  the message and persists it to the database for delivery.

  Referenced template and sender must match the provided `project_id`.

  The `contact` assign is populated with information from the project's
  contacts if a) an existing contact matches the provided `recipient_id`
  or b) if `contact_id` or `external_contact_id` were specified.

  If a template is specifid, `subject` and the body fields are not required and
  will be taken from the template if they're not specified.

  When credits are enabled, consumes one credit per message.
  """
  @spec deliver(Project.id(), map()) :: {:ok, Message.t()} | {:error, error()}
  def deliver(project_id, params) do
    with {:ok, request} <- cast_request(params),
         {:ok, request} <- load_assocs(project_id, request),
         :ok <- ensure_account_active(project_id),
         %{valid?: true} = output <- Renderer.render(to_input(request)),
         :ok <- maybe_consume_credit(project_id) do
      project_id
      |> message_attrs(request, output)
      |> Message.changeset()
      |> Repo.insert()
    else
      %{valid?: false} = output -> {:error, {:rendering_failed, output.errors}}
      error -> error
    end
  end

  @doc """
  Casts, validates and renders a `TransactionalMessage.Request` and returns
  a `Keila.Mailings.Renderer.Output` struct.

  Note that if `{:ok, output}` is returned, the output struct may still contain
  errors. Error tuples are only returned if the parameters provided were invalid.
  """
  @spec preview(Project.id(), map()) :: {:ok, Renderer.Output.t()} | {:error, error()}
  def preview(project_id, params) do
    with {:ok, request} <- cast_request(params),
         {:ok, request} <- load_assocs(project_id, request) do
      {:ok, Renderer.render(to_input(request))}
    end
  end

  defp cast_request(params) do
    params
    |> Request.changeset()
    |> Ecto.Changeset.apply_action(:insert)
  end

  # Loads the referenced sender, template, and contact into the cast Request's
  # virtual fields, defaulting the subject.
  defp load_assocs(project_id, request) do
    with {:ok, sender} <- get_sender(project_id, request.sender_id),
         {:ok, template} <- get_template(project_id, request.template_id),
         {:ok, subject} <- get_subject(request, template),
         {:ok, recipient} <- get_recipient(project_id, request) do
      {:ok,
       %Request{
         request
         | template: template,
           sender: sender,
           contact: recipient.contact,
           recipient_email: recipient.recipient_email,
           recipient_name: recipient.recipient_name,
           subject: subject
       }}
    end
  end

  defp get_sender(project_id, sender_id) do
    case Mailings.get_project_sender(project_id, sender_id) do
      nil -> {:error, :sender_not_found}
      %Sender{} = sender -> {:ok, sender}
    end
  end

  defp get_template(_project_id, nil), do: {:ok, nil}

  defp get_template(project_id, template_id) do
    case Templates.get_project_template(project_id, template_id) do
      nil -> {:error, :template_not_found}
      %Template{} = template -> {:ok, template}
    end
  end

  defp get_subject(%Request{subject: s}, _template) when is_binary(s) and s != "",
    do: {:ok, s}

  defp get_subject(_request, %Template{name: name}) when is_binary(name) and name != "",
    do: {:ok, name}

  defp get_subject(_request, _template), do: {:error, :no_subject}

  defp get_recipient(project_id, %Request{} = request) do
    with {:ok, contact} <- get_contact(project_id, request) do
      email = request.recipient_email || (contact && contact.email)
      name = request.recipient_name || (contact && Contacts.display_name(contact))

      {:ok, %{contact: contact, recipient_email: email, recipient_name: name}}
    end
  end

  defp get_contact(project_id, %{contact_id: id}) when is_binary(id) do
    case Contacts.get_project_contact(project_id, id) do
      nil -> {:error, :contact_not_found}
      %Contact{} = c -> {:ok, c}
    end
  end

  defp get_contact(project_id, %{external_contact_id: ext}) when is_binary(ext) do
    case Contacts.get_project_contact_by_external_id(project_id, ext) do
      nil -> {:error, :contact_not_found}
      %Contact{} = c -> {:ok, c}
    end
  end

  defp get_contact(project_id, %{recipient_email: email}) when is_binary(email) do
    {:ok, Contacts.get_project_contact_by_email(project_id, email)}
  end

  defp get_contact(_project_id, _request), do: {:ok, nil}

  Keila.if_cloud do
    defp ensure_account_active(project_id) do
      case Keila.Accounts.get_project_account(project_id) do
        %{status: :active} -> :ok
        _account -> {:error, :account_not_active}
      end
    end
  else
    defp ensure_account_active(_project_id), do: :ok
  end

  defp maybe_consume_credit(project_id) do
    if Keila.Accounts.credits_enabled?() do
      account = Keila.Accounts.get_project_account(project_id)

      case Keila.Accounts.consume_credits(account.id, 1) do
        :ok -> :ok
        :error -> {:error, :insufficient_credits}
      end
    else
      :ok
    end
  end

  defp to_input(%Request{} = request) do
    %Renderer.Input{
      type: request.type,
      subject: request.subject,
      mjml_body: request.mjml_body,
      html_body: request.html_body,
      text_body: request.text_body,
      mjml_content: request.mjml_content,
      html_content: request.html_content,
      text_content: request.text_content,
      template: request.template,
      contact: request.contact,
      recipient_email: request.recipient_email,
      recipient_name: request.recipient_name,
      assigns: Map.put(request.variables || %{}, "signature", "")
    }
  end

  defp message_attrs(project_id, %Request{sender: sender, contact: contact} = request, output) do
    %{
      "project_id" => project_id,
      "sender_id" => sender.id,
      "contact_id" => contact && contact.id,
      "recipient_email" => request.recipient_email,
      "recipient_name" => request.recipient_name,
      "cc" => request.cc || [],
      "bcc" => request.bcc || [],
      "subject" => output.subject,
      "html_body" => output.html_body,
      "text_body" => output.text_body,
      # Between bulk campaigns (100) and welcome/double-opt-in (10): transactional
      # mail is latency-sensitive but shouldn't fully starve those.
      "priority" => 50,
      "status" => :ready
    }
  end
end
