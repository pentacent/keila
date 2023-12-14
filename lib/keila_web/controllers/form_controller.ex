defmodule KeilaWeb.FormController do
  use KeilaWeb, :controller
  alias Keila.Contacts
  import Phoenix.LiveView.Controller

  plug :authorize when action not in [:index, :new, :delete, :display, :submit, :unsubscribe]

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
    current_project = current_project(conn)

    double_opt_in_available? =
      Keila.Billing.feature_available?(current_project.id, :double_opt_in)

    live_render(conn, KeilaWeb.FormEditLive,
      session: %{
        "current_project" => current_project(conn),
        "form" => conn.assigns.form,
        "locale" => Gettext.get_locale(),
        "double_opt_in_available" => double_opt_in_available?
      }
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
