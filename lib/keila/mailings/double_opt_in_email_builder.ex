defmodule Keila.Mailings.DoubleOptInEmailBuilder do
  @moduledoc """
  Builder for double opt-in confirmation emails.
  """

  use KeilaWeb.Gettext

  alias Keila.Contacts.Form
  alias Keila.Contacts.FormParams
  alias Keila.Templates.{Css, HybridTemplate}
  alias Swoosh.Email
  alias KeilaWeb.Router.Helpers, as: Routes
  alias KeilaWeb.Endpoint

  @doc """
  Builds a double opt-in email for the given `FormParams`.
  `form_params` must be preloaded with the `form` assoc.
  """
  @spec build(FormParams.t(), map()) :: Email.t()
  def build(form_params, assigns \\ %{}) do
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

  @preview_assigns %{
    "double_opt_in_link" => "#double-opt-in-preview-link",
    "unsubscribe_link" => "#unsubscribe-preview-link"
  }

  @doc """
  Builds a preview email for the given form.
  """
  @spec build_preview(Form.t()) :: Email.t()
  def build_preview(form) do
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
end
