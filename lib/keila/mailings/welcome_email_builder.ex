defmodule Keila.Mailings.WelcomeEmailBuilder do
  @moduledoc """
  Builder for welcome emails sent after form submission.
  """

  import KeilaWeb.Gettext

  alias Keila.Contacts.Contact
  alias Keila.Contacts.Form
  alias Keila.Templates.{Css, HybridTemplate}
  alias Swoosh.Email
  alias KeilaWeb.Router.Helpers, as: Routes
  alias KeilaWeb.Endpoint

  @doc """
  Builds a welcome email for the given `Contact` and `Form`.
  """
  @spec build(Contact.t(), Form.t(), map()) :: Email.t()
  def build(contact, form, assigns \\ %{}) do
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

  @preview_contact %Keila.Contacts.Contact{
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
  @spec build_preview(Form.t(), Contact.t()) :: Email.t()
  def build_preview(form, contact \\ @preview_contact) do
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
end
