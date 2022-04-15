defmodule Keila.Mailings.Builder do
  @moduledoc """
  Module for building Swoosh.Email structs from Campaigns and Contacts.

  The Liquid templating language can be used within email bodies. Use
  `assigns` to pass values to templates.

  Adds `X-Keila-Invalid` header if there was an error creating the email.
  Such emails should not be delivered.
  """

  alias Keila.Contacts.Contact
  alias Keila.Mailings.Campaign
  alias KeilaWeb.Router.Helpers, as: Routes
  use Keila.Mailings.Email
  import Floki, only: [find_and_update: 3, traverse_and_update: 2]

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
  @spec build(Campaign.t(), Contact.t(), map()) :: Email.t()
  def build(campaign, recipient \\ @default_contact, assigns) do
    unsubscribe_link =
      Routes.form_url(KeilaWeb.Endpoint, :unsubscribe, campaign.project_id, recipient.id)

    try do
      new()
      |> from(campaign.sender)
      |> to(recipient)
      |> reply_to(campaign)
      |> subject(campaign.subject)
      |> put_unsubscribe_header(unsubscribe_link)
      |> maybe_put_precedence_header()
      |> maybe_put_tracking(campaign, recipient)
    catch
      {email, error} ->
        header(email, "X-Keila-Invalid", error)
    end
  end

  defp process_assigns(value) when is_number(value) or is_binary(value) or is_nil(value),
    do: value

  defp process_assigns(value) when is_atom(value), do: Atom.to_string(value)
  defp process_assigns(value) when is_tuple(value), do: Tuple.to_list(value)
  defp process_assigns(value) when is_struct(value), do: process_assigns(Map.from_struct(value))

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

  # TODO add campaign settings for disabling/configuring tracking
  defp maybe_put_tracking(email, campaign, recipient) do
    if email.html_body && recipient do
      put_tracking(email, campaign, recipient)
    else
      email
    end
  end

  defp put_unsubscribe_header(email, unsubscribe_link) do
    email
    |> header("List-Unsubscribe", "<#{unsubscribe_link}>")
    |> header("List-Unsubscribe-Post", "List-Unsubscribe=One-Click")
  end

  defp put_tracking(email, campaign, recipient) do
    modified_ast =
      get_ast(email)
      |> put_click_tracking(campaign, recipient)
      |> put_open_tracking(campaign, recipient)
      |> put_tracking_pixel(campaign, recipient)

    put_ast(email, modified_ast)
  end

  @tracking_click_selector "a[href^=\"https://\"], a[href^=\"http://\"]"
  defp put_click_tracking(ast_tree, campaign, recipient) do
    find_and_update(ast_tree, @tracking_click_selector, fn {tag, attributes} ->
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
  defp put_open_tracking(ast_tree, campaign, recipient) do
    find_and_update(ast_tree, @tracking_open_selector, fn {tag, attributes} ->
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

  defp put_tracking_pixel(ast_tree, campaign, recipient) do
    pixel_url = Routes.static_url(KeilaWeb.Endpoint, "/images/pixel.gif")
    params = %{url: pixel_url, campaign_id: campaign.id, recipient_id: recipient.id}
    url = Keila.Tracking.get_tracking_url(KeilaWeb.Endpoint, :open, params)

    img = {"img", [{"src", url}], []}

    traverse_and_update(ast_tree, fn
      {"body", tags, children} -> {"body", tags, children ++ [img]}
      other -> other
    end)
  end
end
