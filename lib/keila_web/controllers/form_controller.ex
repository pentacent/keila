defmodule KeilaWeb.FormController do
  use KeilaWeb, :controller
  alias Keila.{Contacts, Contacts.Contact}
  import Ecto.Changeset
  import Phoenix.LiveView.Controller

  plug :fetch when action in [:display, :submit]
  plug :authorize when action not in [:index, :new, :display, :submit, :unsubscribe, :delete]

  @spec display(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def display(conn, _params) do
    form = conn.assigns.form

    render_display(conn, change(%Contact{}), form)
  end

  @spec submit(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def submit(conn, params) do
    form = conn.assigns.form

    if !form.settings.captcha_required or
         KeilaWeb.Hcaptcha.captcha_valid?(params["h-captcha-response"]) do
      case Contacts.create_contact(form.project_id, params["contact"] || %{}) do
        {:ok, _contact} ->
          render(conn, "form_success.html")

        {:error, changeset} ->
          render_display(conn, 400, changeset, form)
      end
    else
      {:error, changeset} =
        params["contact"]
        |> Contacts.Contact.changeset_from_form(form)
        |> Ecto.Changeset.add_error(:hcaptcha, dgettext("auth", "Please complete the captcha."))
        |> Ecto.Changeset.apply_action(:insert)

      render_display(conn, 400, changeset, form)
    end
  end

  defp render_display(conn, status \\ 200, changeset, form) do
    conn
    |> put_status(status)
    |> put_meta(:title, form.name)
    |> assign(:changeset, changeset)
    |> assign(:mode, :full)
    |> render("form.html")
  end

  @default_unsubscribe_form %Contacts.Form{settings: %Contacts.Form.Settings{}}
  @spec unsubscribe(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def unsubscribe(conn, %{"project_id" => project_id, "contact_id" => contact_id}) do
    form = Contacts.get_project_forms(project_id) |> List.first() || @default_unsubscribe_form
    contact = Contacts.get_project_contact(project_id, contact_id)

    if contact do
      Contacts.delete_contact(contact.id)
    end

    conn
    |> put_meta(:title, gettext("Unsubscribe"))
    |> assign(:form, form)
    |> assign(:mode, :full)
    |> render("unsubscribe.html")
  end

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    forms = Contacts.get_project_forms(current_project(conn).id)

    conn
    |> assign(:forms, forms)
    |> put_meta(:title, gettext("Forms"))
    |> render("index.html")
  end

  @spec new(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def new(conn, _params) do
    project = current_project(conn)
    {:ok, form} = Contacts.create_empty_form(project.id)
    redirect(conn, to: Routes.form_path(conn, :edit, project.id, form.id))
  end

  @spec edit(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def edit(conn, _params) do
    live_render(conn, KeilaWeb.FormEditLive,
      session: %{"current_project" => current_project(conn), "form" => conn.assigns.form}
    )
  end

  @spec post_edit(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def post_edit(conn, params) do
    params = params["form"] || %{}
    form_id = conn.assigns.form.id

    {:ok, _form} = Contacts.update_form(form_id, params)
    redirect(conn, to: Routes.form_path(conn, :index, current_project(conn).id))
  end

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, params) do
    ids =
      case get_in(params, ["form", "id"]) do
        ids when is_list(ids) -> ids
        id when is_binary(id) -> [id]
      end

    case get_in(params, ["form", "require_confirmation"]) do
      "true" ->
        render_delete_confirmation(conn, ids)

      _ ->
        :ok = Contacts.delete_project_forms(current_project(conn).id, ids)

        redirect(conn, to: Routes.form_path(conn, :index, current_project(conn).id))
    end
  end

  defp render_delete_confirmation(conn, ids) do
    forms =
      Contacts.get_project_forms(current_project(conn).id)
      |> Enum.filter(&(&1.id in ids))

    conn
    |> put_meta(:title, gettext("Confirm Form Deletion"))
    |> assign(:forms, forms)
    |> render("delete.html")
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

  defp current_project(conn), do: conn.assigns.current_project

  defp authorize(conn, _) do
    project_id = current_project(conn).id
    form_id = conn.path_params["id"]

    case Contacts.get_project_form(project_id, form_id) do
      nil ->
        conn
        |> put_status(404)
        |> halt()

      form ->
        assign(conn, :form, form)
    end
  end
end
