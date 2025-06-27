defmodule KeilaWeb.PublicFormController do
  use KeilaWeb, :controller
  require Logger
  alias Keila.{Contacts, Mailings, Tracking}
  alias Keila.Contacts.Contact
  alias Keila.Contacts.FormParams
  import Ecto.Changeset

  plug :fetch when action in [:show, :submit]
  plug :fetch_form_params when action in [:double_opt_in, :cancel_double_opt_in]

  plug :maybe_put_protect_from_forgery
       when action in [:show, :submit, :double_opt_in, :cancel_double_opt_in]

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, _params) do
    form = conn.assigns.form
    changeset = Keila.Contacts.Contact.changeset_from_form(%{}, form)

    render_form(conn, changeset, form)
  end

  plug :check_honeypot when action == :submit
  @spec submit(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def submit(conn, params) do
    form = conn.assigns.form
    contact_params = params["contact"] || %{}

    opts =
      if form.settings.captcha_required,
        do: [changeset_transform: check_captcha_changeset_transform(params)],
        else: []

    case Contacts.perform_form_action(form, contact_params, opts) do
      {:ok, contact = %Contact{}} ->
        data = if form.settings.captcha_required, do: %{"captcha" => true}, else: %{}
        Tracking.log_event("subscribe", contact.id, data)

        render_success_or_redirect(conn)

      {:ok, form_params = %FormParams{}} ->
        conn
        |> assign(:email, form_params.params[:email])
        |> render_double_opt_in_required_or_redirect()

      {:error, changeset} ->
        render_form(conn, 400, changeset, form)
    end
  end

  defp check_captcha_changeset_transform(params) do
    fn changeset ->
      captcha_response = KeilaWeb.Captcha.get_captcha_response(params)

      if KeilaWeb.Captcha.captcha_valid?(captcha_response) do
        changeset
      else
        changeset
        |> add_error(:captcha, dgettext("auth", "Please complete the captcha."))
      end
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

  def double_opt_in(conn, %{"hmac" => hmac}) do
    form = conn.assigns.form
    form_params = conn.assigns.form_params

    params =
      form_params.params
      |> Map.put("form_params_id", form_params.id)
      |> Map.put("double_opt_in_hmac", hmac)

    case Contacts.perform_form_action(form, params) do
      {:ok, %Contact{id: id}} ->
        data = %{"double_opt_in" => true}
        Tracking.log_event("subscribe", id, data)
        Contacts.delete_form_params(form_params.id)

        render_success_or_redirect(conn)

      {:ok, form_params = %FormParams{}} ->
        conn
        |> assign(:email, form_params.params[:email])
        |> render_double_opt_in_required_or_redirect()

      {:error, changeset} ->
        render_form(conn, 400, changeset, form)
    end
  end

  defp render_success_or_redirect(conn) do
    case conn.assigns.form.settings.success_url do
      url when url not in [nil, ""] -> redirect(conn, external: url)
      _other -> render(conn, "success.html")
    end
  end

  defp render_double_opt_in_required_or_redirect(conn) do
    case conn.assigns.form.settings.double_opt_in_url do
      url when url not in [nil, ""] -> redirect(conn, external: url)
      _other -> render(conn, "double_opt_in_required.html")
    end
  end

  def cancel_double_opt_in(conn, %{"hmac" => hmac}) do
    form = conn.assigns.form
    form_params = conn.assigns.form_params

    if Contacts.valid_double_opt_in_hmac?(hmac, form.id, form_params.id) do
      :ok = Contacts.delete_form_params(form_params.id)

      render(conn, "double_opt_in_cancelled.html")
    else
      conn |> redirect(to: Routes.public_form_path(conn, :show, form.id))
    end
  end

  @default_unsubscribe_form %Contacts.Form{settings: %Contacts.Form.Settings{}}
  @spec unsubscribe(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def unsubscribe(conn = %{method: "GET"}, %{
        "project_id" => project_id,
        "recipient_id" => recipient_id,
        "hmac" => hmac
      }) do
    if Mailings.valid_unsubscribe_hmac?(project_id, recipient_id, hmac) do
      form = Contacts.get_project_forms(project_id) |> List.first() || @default_unsubscribe_form

      conn
      |> put_meta(:title, gettext("Unsubscribe"))
      |> assign(:form, form)
      |> assign(:project_id, project_id)
      |> assign(:recipient_id, recipient_id)
      |> assign(:hmac, hmac)
      |> assign(:mode, :full)
      |> render("unsubscribe.html")
    else
      conn |> put_status(404) |> halt()
    end
  end

  def unsubscribe(conn = %{method: "POST"}, %{
        "project_id" => project_id,
        "recipient_id" => recipient_id,
        "hmac" => hmac
      }) do
    # Validate HMAC and unsubscribe on any POST
    if Mailings.valid_unsubscribe_hmac?(project_id, recipient_id, hmac) do
      Keila.Mailings.unsubscribe_recipient(recipient_id)

      form = Contacts.get_project_forms(project_id) |> List.first() || @default_unsubscribe_form

      conn
      |> put_meta(:title, gettext("Unsubscribed"))
      |> assign(:form, form)
      |> assign(:project_id, project_id)
      |> assign(:recipient_id, recipient_id)
      |> assign(:hmac, hmac)
      |> assign(:mode, :full)
      |> render("unsubscribe_success.html")
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
    |> render("unsubscribe_deprecated.html")
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

  defp fetch_form_params(conn, _) do
    form = conn.path_params["form_id"] |> Contacts.get_form()
    form_params = conn.path_params["form_params_id"] |> Contacts.get_form_params()

    cond do
      form && form_params ->
        conn |> assign(:form, form) |> assign(:form_params, form_params)

      form ->
        conn |> redirect(to: Routes.public_form_path(conn, :show, form.id))

      true ->
        conn |> put_status(404) |> halt()
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

  defp check_honeypot(conn, _) do
    honeypot_values =
      (conn.params["h"] || %{})
      |> Enum.map(fn {_k, value} -> value end)
      |> Enum.filter(&(is_binary(&1) and &1 != ""))

    if Enum.empty?(honeypot_values) do
      conn
    else
      Logger.debug("Blocked form submission with honeypot fields #{inspect(conn.remote_ip)}")
      :timer.sleep(500)

      conn
      |> render_success_or_redirect()
      |> halt()
    end
  end
end
