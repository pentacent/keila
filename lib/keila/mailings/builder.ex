defmodule Keila.Mailings.Builder do
  @moduledoc """
  Module for building Swoosh.Email structs from Campaigns and Contacts.
  """

  alias Keila.Mailings.Campaign
  alias Keila.Contacts.Contact
  alias Swoosh.Email
  alias KeilaWeb.Router.Helpers, as: Routes
  alias Keila.Templates.{Template, Css, Html, DefaultTemplate}
  import Swoosh.Email

  @default_contact %Keila.Contacts.Contact{
    id: "c_id",
    first_name: "Jane",
    last_name: "Doe",
    email: "jane.doe@example.com"
  }

  @doc """
  Builds a `Swoosh.Email` struct from a Campaign, Contact, and assigns.

  `contact` is automatically merged into assigns. If no contact is provided
  (e.g. when building a preview), a default contact is injected.

  The Liquid tempplating language can be used within email bodies.

  Adds `X-Keila-Invalid` header if there was an error creating the email.
  Such emails should not be delivered.

  TODO: Right now, only plain-text campaigns are supported.
  """
  @spec build(Campaign.t(), Contact.t(), map()) :: Swoosh.Email.t()
  def build(campaign, contact \\ @default_contact, assigns) do
    unsubscribe_link =
      Routes.form_url(KeilaWeb.Endpoint, :unsubscribe, campaign.project_id, contact.id)

    assigns =
      assigns
      |> put_template_assigns(campaign.template)
      |> process_assigns()
      |> Map.put_new("contact", process_assigns(contact))
      |> Map.put("unsubscribe_link", unsubscribe_link)

    Email.new()
    |> subject(campaign.subject)
    |> put_recipient(contact)
    |> put_sender(campaign)
    |> maybe_put_reply_to(campaign)
    |> put_body(campaign, assigns)
    |> put_unsubscribe_header(unsubscribe_link)
  end

  defp put_template_assigns(assigns, %Template{assigns: template_assigns = %{}}),
    do: Map.merge(template_assigns, assigns)

  defp put_template_assigns(assigns, _), do: assigns

  defp process_assigns(value) when is_number(value) or is_binary(value) or is_nil(value) do
    value
  end

  defp process_assigns(value) when is_atom(value) do
    Atom.to_string(value)
  end

  defp process_assigns(value) when is_tuple(value) do
    Tuple.to_list(value)
  end

  defp process_assigns(value) when is_struct(value) do
    process_assigns(Map.from_struct(value))
  end

  defp process_assigns(value) when is_map(value) do
    Enum.map(value, fn {key, value} ->
      key = to_string(key)
      value = process_assigns(value)
      {key, value}
    end)
    |> Enum.filter(fn
      {"__" <> _, _} -> false
      _ -> true
    end)
    |> Enum.into(%{})
  end

  defp process_assigns(value) when is_map(value) do
    Enum.map(value, &process_assigns/1)
  end

  defp put_recipient(email, contact) do
    name =
      [contact.first_name, contact.last_name]
      |> Enum.join(" ")
      |> String.trim()

    to(email, [{name, contact.email}])
  end

  defp put_sender(email, campaign) do
    from(email, {campaign.sender.from_name, campaign.sender.from_email})
  end

  defp maybe_put_reply_to(email, campaign) do
    if campaign.sender.reply_to_email do
      reply_to(email, {campaign.sender.reply_to_name, campaign.sender.reply_to_email})
    else
      email
    end
  end

  defp put_body(email, campaign, assigns)

  defp put_body(email, campaign = %{settings: %{type: :text}}, assigns) do
    case render_liquid(campaign.text_body || "", assigns) do
      {:ok, text_body} ->
        text_body(email, text_body)

      {:error, error} ->
        email
        |> header("X-Keila-Invalid", error)
        |> text_body(error)
    end
  end

  defp put_body(email, campaign = %{settings: %{type: :markdown}}, assigns) do
    main_content = campaign.text_body || ""
    signature_content = assigns["signature"] || "[Unsubscribe]({{ unsubscribe_link }})"

    with {:ok, main_content_text} <- render_liquid(main_content, assigns),
         {:ok, main_content_html, _} <- Earmark.as_html(main_content_text),
         {:ok, signature_content_text} <- render_liquid(signature_content, assigns),
         {:ok, signature_content_html, _} <- Earmark.as_html(signature_content_text),
         assigns <- Map.put(assigns, "main_content", main_content_html),
         assigns <- Map.put(assigns, "signature_content", signature_content_html),
         {:ok, html_body} <- render_liquid(DefaultTemplate.html_template(), assigns) do
      styles = fetch_styles(campaign)

      text_body = main_content_text <> "\n\n--  \n" <> signature_content_text

      html_body =
        html_body
        |> Html.parse_document!()
        |> Html.apply_inline_styles(styles)
        |> Html.to_document()

      email
      |> text_body(text_body)
      |> html_body(html_body)
    else
      _other -> email
    end
  end

  defp fetch_styles(campaign)

  defp fetch_styles(%Campaign{template: %Template{styles: styles}}) when is_list(styles) do
    default_styles = DefaultTemplate.styles()
    template_styles = styles
    Css.merge(default_styles, template_styles)
  end

  defp fetch_styles(%Campaign{template: %Template{styles: styles}}) when is_binary(styles) do
    default_styles = DefaultTemplate.styles()
    template_styles = Css.parse!(styles)
    Css.merge(default_styles, template_styles)
  end

  defp fetch_styles(_) do
    DefaultTemplate.styles()
  end

  defp put_unsubscribe_header(email, unsubscribe_link) do
    email
    |> header("List-Unsubscribe", "<#{unsubscribe_link}>")
    |> header("List-Unsubscribe-Post", "List-Unsubscribe=One-Click")
  end

  defp render_liquid(input, assigns) when is_binary(input) do
    try do
      with {:ok, template} <- Solid.parse(input) do
        render_liquid(template, assigns)
      else
        {:error, error = %Solid.TemplateError{}} -> {:error, error.message}
      end
    rescue
      _e -> {:error, "Unexpected parsing error"}
    end
  end

  defp render_liquid(input = %Solid.Template{}, assigns) do
    try do
      input
      |> Solid.render(assigns)
      |> to_string()
      |> (fn output -> {:ok, output} end).()
    rescue
      _e -> {:error, "Unexpected rendering error"}
    end
  end
end
