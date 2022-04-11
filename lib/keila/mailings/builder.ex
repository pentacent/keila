defmodule Keila.Mailings.Builder do
  @moduledoc """
  Module for building Swoosh.Email structs from Campaigns and Contacts.
  """

  alias Keila.Mailings.{Campaign, Recipient}
  alias Keila.Contacts.Contact
  alias Swoosh.Email
  alias KeilaWeb.Router.Helpers, as: Routes
  alias Keila.Templates.{Template, Css, Html, DefaultTemplate}
  import Swoosh.Email, only: [header: 3, html_body: 2, subject: 2, text_body: 2]

  @default_contact %Keila.Contacts.Contact{
    id: "c_id",
    first_name: "Jane",
    last_name: "Doe",
    email: "jane.doe@example.com",
    data: %{"tags" => ["rocket-scientist"]}
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
  @spec build(Campaign.t(), Recipient.t() | Contact.t(), map()) :: Swoosh.Email.t()
  def build(campaign, recipient_or_contact \\ @default_contact, assigns) do
    {recipient, contact} =
      case recipient_or_contact do
        recipient = %Recipient{} -> {recipient, recipient.contact}
        contact = %Contact{} -> {nil, contact}
      end

    unsubscribe_link =
      Routes.form_url(KeilaWeb.Endpoint, :unsubscribe, campaign.project_id, contact.id)

    assigns =
      assigns
      |> put_template_assigns(campaign.template)
      |> process_assigns()
      |> Map.put_new("contact", process_assigns(contact))
      |> Map.put_new("campaign", process_assigns(Map.take(campaign, [:data, :subject])))
      |> Map.put("unsubscribe_link", unsubscribe_link)

    Email.new()
    |> from(campaign)
    |> to(contact)
    |> reply_to(campaign)
    |> subject(campaign.subject)
    |> render_liquid(:subject, assigns)
    |> put_template(campaign)
    |> fill_template(campaign, assigns)
    |> put_unsubscribe_header(unsubscribe_link)
    |> maybe_put_precedence_header()
    |> maybe_put_tracking(campaign, recipient)
  end

  defp append(email, :error, error), do: append(email, :text, error)

  defp append(email, :html, html) do
    html_body(email, email.html_body || "" <> html)
  end

  defp append(email, :text, text) do
    text_body(email, email.text_body || "" <> text)
  end

  defp append(email, :markdown, markdown, options \\ %Earmark.Options{}) do
    html = case Earmark.as_html(markdown, options) do
      {:ok, html, _messages} -> html
      {:error, html, messages} ->
        IO.puts([html, messages])
        {html, messages}
      end
    email
    |> append(:html, html)
    |> append(:text, markdown)
  end

  defp apply_styles(email, campaign) do
    styles = fetch_styles(campaign)
    styled_body = email.html_body
    |> Html.parse_document!()
    |> Html.apply_email_markup()
    |> Html.apply_inline_styles(styles, ignore_inherit: true)
    |> Html.to_document()
    %{email | html_body: styled_body}
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

  defp process_assigns(value) when is_list(value) do
    Enum.map(value, &process_assigns/1)
  end

  @spec to(Email.t, Recipient.t) :: Email.t
  defp to(email, recipient = %Recipient{}), do: to(email, recipient.contact)

  @spec to(Email.t, Contact.t) :: Email.t
  defp to(email, contact = %Contact{}) do
    name =
      [contact.first_name, contact.last_name]
      |> Enum.join(" ")
      |> String.trim()

    Email.to(email, [{name, contact.email}])
  end

  @spec from(Email.t, Campaign.t) :: Email.t
  defp from(email, campaign = %Campaign{}) do
    Email.from(email, {campaign.sender.from_name, campaign.sender.from_email})
  end

  @spec reply_to(Email.t, Campaign.t) :: Email.t
  defp reply_to(email, campaign = %Campaign{}) do
    if campaign.sender.reply_to_email do
      Email.reply_to(email, {campaign.sender.reply_to_name, campaign.sender.reply_to_email})
    else
      email
    end
  end

  @spec fill_template(Email.t, Campaign.t, map()) :: Email.t
  defp fill_template(email, campaign, assigns) do
    content_type = campaign.settings.type
    preferred_content = case content_type do
      :markdown -> campaign.html_body || campaign.text_body
      :text -> campaign.text_body || campaign.html_body
    end
    case render_liquid(preferred_content, assigns) do
      {:ok, rendered_content} ->
      email
        |> append(content_type, rendered_content)
        |> apply_styles(campaign)
      {:error, error} ->
        email
        |> Email.header("X-Keila-Invalid", error)
        |> append(:error, error)
    end
  end
  # assigns <- Map.put(assigns, "main_content", main_content_html),
  # assigns <- Map.put(assigns, "signature_content", signature_content_html),
  #{:ok, html_body} <- render_liquid(DefaultTemplate.html_template(), assigns)

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

  defp maybe_put_precedence_header(email) do
    enable_precedence_header =
      Application.get_env(:keila, Keila.Mailings)
      |> Keyword.fetch!(:enable_precedence_header)

    if enable_precedence_header do
      header(email, "Precedence", "Bulk")
    else
      email
    end
  end

  defp render_liquid(email, key, assigns) when is_atom(key) do
    unredered_content = Map.fetch!(email, key)
    case render_liquid(unredered_content, assigns) do
      {:ok, rendered_content} -> %{email | key => rendered_content}
    end
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

  # TODO add campaign settings for disabling/configuring tracking
  defp maybe_put_tracking(email, campaign, recipient) do
    if email.html_body && recipient do
      put_tracking(email, campaign, recipient)
    else
      email
    end
  end

  def put_tracking(email, campaign, recipient) do
    html =
      email.html_body
      |> Floki.parse_document!()
      |> put_click_tracking(campaign, recipient)
      |> put_open_tracking(campaign, recipient)
      |> put_tracking_pixel(campaign, recipient)
      |> Floki.raw_html()

    %{email | html_body: html}
  end

  @tracking_click_selector "a[href^=\"https://\"], a[href^=\"http://\"]"
  defp put_click_tracking(html, campaign, recipient) do
    Floki.find_and_update(html, @tracking_click_selector, fn {tag, attributes} ->
      href = List.keyfind(attributes, "href", 0) |> elem(1)
      # if not keila link
      if String.starts_with?(href, KeilaWeb.Endpoint.url()) do
        {tag, attributes}
      else
        link = Keila.Tracking.get_or_register_link(href, campaign.id)

        params = %{
          url: href,
          campaign_id: campaign.id,
          recipient_id: recipient.id,
          link_id: link.id
        }

        url = Keila.Tracking.get_tracking_url(KeilaWeb.Endpoint, :click, params)

        {tag, List.keyreplace(attributes, "href", 0, {"href", url})}
      end
    end)
  end

  @tracking_open_selector "img[src^=\"https://\"], img[src^=\"http://\"]"
  defp put_open_tracking(html, campaign, recipient) do
    Floki.find_and_update(html, @tracking_open_selector, fn {tag, attributes} ->
      src = List.keyfind(attributes, "src", 0) |> elem(1)

      if String.starts_with?(src, KeilaWeb.Endpoint.url()) do
        {tag, attributes}
      else
        params = %{url: src, campaign_id: campaign.id, recipient_id: recipient.id}
        url = Keila.Tracking.get_tracking_url(KeilaWeb.Endpoint, :open, params)

        {tag, List.keyreplace(attributes, "src", 0, {"src", url})}
      end
    end)
  end

  defp put_tracking_pixel(html, campaign, recipient) do
    pixel_url = Routes.static_url(KeilaWeb.Endpoint, "/images/pixel.gif")
    params = %{url: pixel_url, campaign_id: campaign.id, recipient_id: recipient.id}
    url = Keila.Tracking.get_tracking_url(KeilaWeb.Endpoint, :open, params)

    img = {"img", [{"src", url}], []}

    Floki.traverse_and_update(html, fn
      {"body", tags, children} -> {"body", tags, children ++ [img]}
      other -> other
    end)
  end
end
