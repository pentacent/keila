defmodule KeilaWeb.PublicFormController do
  use KeilaWeb, :controller
  alias Keila.{Contacts, Mailings, Tracking}
  alias Keila.Contacts.Contact
  import Ecto.Changeset

  plug :fetch when action in [:show, :submit]
  plug :maybe_put_protect_from_forgery when action in [:show, :submit]

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, _params) do
    form = conn.assigns.form

    Keil
    render_form(conn, change(%Contact{}), form)
  end

  @spec submit(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def submit(conn, params) do
    form = conn.assigns.form
    contact_params = params["contact"] || %{}

    with :ok <- maybe_check_captcha(form, params),
         {:ok, %{id: id}} <- Contacts.create_contact_from_form(form, contact_params) do
      data = %{"captcha" => form.settings.captcha_required}
      Tracking.log_event("subscribe", id, data)

      render(conn, "success.html")
    else
      {:error, changeset} -> render_form(conn, 400, changeset, form)
    end
  end

  defp maybe_check_captcha(%{settings: %{captcha_required: false}}, _), do: :ok

  defp maybe_check_captcha(form, params) do
    captcha_response = KeilaWeb.Captcha.get_captcha_response(params)

    if KeilaWeb.Captcha.captcha_valid?(captcha_response) do
      :ok
    else
      params["contact"]
      |> Contacts.Contact.changeset_from_form(form)
      |> Ecto.Changeset.add_error(:captcha, dgettext("auth", "Please complete the captcha."))
      |> Ecto.Changeset.apply_action(:insert)
    end
  end

  defp render_form(conn, status \\ 200, changeset, form) do
    conn
    |> put_status(status)
    |> put_meta(:title, form.name)
    |> assign(:changeset, changeset)
    |> assign(:mode, :full)
    |> render("show.html")
  end

  @default_unsubscribe_form %Contacts.Form{settings: %Contacts.Form.Settings{}}
  @spec unsubscribe(Plug.Conn.t(), map()) :: Plug.Conn.t()

  def unsubscribe(conn, %{
        "project_id" => project_id,
        "recipient_id" => recipient_id,
        "hmac" => hmac
      }) do
    if Mailings.valid_unsubscribe_hmac?(project_id, recipient_id, hmac) do
      Keila.Mailings.unsubscribe_recipient(recipient_id)

      form = Contacts.get_project_forms(project_id) |> List.first() || @default_unsubscribe_form

      conn
      |> put_meta(:title, gettext("Unsubscribe"))
      |> assign(:form, form)
      |> assign(:mode, :full)
      |> render("unsubscribe.html")
    else
      conn |> put_status(404) |> halt()
    end
  end

  # DEPRECATED: This implementation is deprecated and will be removed in a future version
  def unsubscribe(conn, %{"project_id" => project_id, "contact_id" => contact_id}) do
    form = Contacts.get_project_forms(project_id) |> List.first() || @default_unsubscribe_form
    contact = Contacts.get_project_contact(project_id, contact_id)

    if contact && contact.status != :unsubscribed do
      Keila.Contacts.update_contact_status(contact_id, :unsubscribed)
      Keila.Tracking.log_event("unsubscribe", contact_id, %{})
    end

    conn
    |> put_meta(:title, gettext("Unsubscribe"))
    |> assign(:form, form)
    |> assign(:mode, :full)
    |> render("unsubscribe.html")
  end

  defp fetch(conn, _) do
    form_id = conn.path_params["id"]

    case Contacts.get_form(form_id) do
      nil ->
        conn
        |> put_status(404)
        |> halt()

      form ->
        assign(conn, :form, form)
    end
  end

  defp maybe_put_protect_from_forgery(conn, _) do
    form = conn.assigns.form

    if form.settings.csrf_disabled do
      conn
    else
      protect_from_forgery(conn)
    end
  end
end
