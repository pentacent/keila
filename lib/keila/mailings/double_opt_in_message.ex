defmodule Keila.Mailings.DoubleOptInMessage do
  @moduledoc """
  Module for building and delivering double opt-in confirmation email messages.
  """

  require Keila

  use KeilaWeb.Gettext
  use Keila.Repo

  alias Keila.Contacts
  alias Keila.Contacts.Form
  alias Keila.Contacts.FormParams
  alias Keila.Mailings.Message
  alias Keila.Templates.{Css, HybridTemplate}
  alias Swoosh.Email
  alias KeilaWeb.Router.Helpers, as: Routes
  alias KeilaWeb.Endpoint

  @doc """
  Renders a double opt-in email for the given `form_params_id` and inserts a
  Message with `status: :ready` and `priority: 10`.

  Returns `{:ok, message}` on success or `{:error, reason}` on failure.
  """
  def deliver(form_params_id) do
    form_params = Contacts.get_form_params(form_params_id) |> Repo.preload(:form)
    sender = Keila.Mailings.get_sender(form_params.form.sender_id)
    project_id = form_params.form.project_id

    with :ok <- ensure_feature_available(project_id),
         :ok <- ensure_account_active(project_id),
         :ok <- ensure_sender(sender),
         email <- build(form_params),
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
        form_id: form_params.form_id,
        form_params_id: form_params.id
      })
      |> Repo.insert()
    end
  end

  @preview_assigns %{
    "double_opt_in_link" => "#double-opt-in-preview-link",
    "unsubscribe_link" => "#unsubscribe-preview-link"
  }

  @doc """
  Builds a preview email for the given form.
  """
  @spec preview(Form.t()) :: Email.t()
  def preview(form) do
    preview_form_params = %FormParams{
      id: "preview_id",
      form_id: form.id,
      form: form,
      params: %{
        "email" => "test@example.com",
        "first_name" => "Jane",
        "last_name" => "Doe",
        "data" => %{}
      }
    }

    build(preview_form_params, @preview_assigns)
  end

  @doc """
  Returns the default subject for a double opt-in email.
  """
  @spec default_subject() :: String.t()
  def default_subject() do
    gettext("Please confirm your email address")
  end

  @doc """
  Returns the default markdown body for a double opt-in email.
  """
  @spec default_markdown_body() :: String.t()
  def default_markdown_body() do
    gettext("""
    # Email Confirmation

    Please click here to confirm your subscription:

    #### [Confirm subscription]({{ double_opt_in_link }})
    """)
  end

  # Building

  defp build(form_params, assigns \\ %{}) do
    form = form_params.form
    subject = get_subject(form)
    body_markdown = get_body_markdown(form)

    template = if form.template_id, do: Keila.Templates.get_template(form.template_id)
    styles = get_styles(template)

    assigns = build_assigns(assigns, form_params, template, subject)

    Email.new()
    |> Email.to(form_params.params["email"])
    |> Email.subject(subject)
    |> Keila.Mailings.Builder.Markdown.put_body(body_markdown, styles, assigns)
  end

  defp get_subject(form) do
    case form.settings.double_opt_in_subject do
      empty when empty in [nil, ""] -> default_subject()
      subject -> subject
    end
  end

  defp get_body_markdown(form) do
    case form.settings.double_opt_in_markdown_body do
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

  defp build_assigns(assigns, form_params, template, subject) do
    form = form_params.form

    assigns
    |> Map.put_new_lazy("double_opt_in_link", fn -> get_double_opt_in_link(form, form_params) end)
    |> Map.put_new_lazy("unsubscribe_link", fn -> get_unsubscribe_link(form, form_params) end)
    |> Map.put("contact", form_params.params)
    |> Map.put("campaign", %{"subject" => subject})
    |> Map.put("signature", if(template, do: template.assigns["signature"]))
  end

  defp get_double_opt_in_link(form, form_params) do
    hmac = Keila.Contacts.double_opt_in_hmac(form_params.form_id, form_params.id)
    Routes.public_form_url(Endpoint, :double_opt_in, form.id, form_params.id, hmac)
  end

  defp get_unsubscribe_link(form, form_params) do
    hmac = Keila.Contacts.double_opt_in_hmac(form_params.form_id, form_params.id)
    Routes.public_form_url(Endpoint, :cancel_double_opt_in, form.id, form_params.id, hmac)
  end

  # Helpers

  defp ensure_valid_email(email) do
    if Enum.find(email.headers, fn {name, _} -> name == "X-Keila-Invalid" end) do
      {:error, :rendering_error}
    else
      :ok
    end
  end

  Keila.if_cloud do
    defp ensure_feature_available(project_id) do
      if KeilaCloud.Billing.feature_available?(project_id, :double_opt_in) do
        :ok
      else
        {:error, "Double opt-in not enabled for account of project #{project_id}"}
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
