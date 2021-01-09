defmodule KeilaWeb.SenderController do
  use KeilaWeb, :controller
  alias Keila.Mailings
  import Ecto.Changeset

  plug :authorize when not (action in [:index, :new, :post_new])

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    senders = Mailings.list_senders(current_project(conn).id)

    conn
    |> assign(:senders, senders)
    |> put_meta(:title, gettext("Senders"))
    |> render("index.html")
  end

  @spec edit(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def edit(conn, _params) do
    conn
    |> put_meta(:title, conn.assigns.sender.name)
    |> render_edit(Ecto.Changeset.change(conn.assigns.sender))
  end

  @spec post_edit(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def post_edit(conn, params = %{"id" => id}) do
    project = current_project(conn)

    case Mailings.update_sender(id, params["sender"] || %{}) do
      {:ok, _sender} -> redirect(conn, to: Routes.sender_path(conn, :index, project.id))
      {:error, changeset} -> render_edit(conn, 400, changeset)
    end
  end

  @spec new(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def new(conn, _) do
    changeset =
      Ecto.Changeset.change(%Mailings.Sender{}, %{
        config: Ecto.Changeset.change(%Mailings.Sender.Config{}, %{type: "smtp"})
      })

    render_edit(conn, changeset)
  end

  @spec post_new(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def post_new(conn, %{"sender" => params}) do
    project = current_project(conn)

    case Mailings.create_sender(project.id, params) do
      {:ok, _} -> redirect(conn, to: Routes.sender_path(conn, :index, project.id))
      {:error, changeset} -> render_edit(conn, 400, changeset)
    end
  end

  defp render_edit(conn, status \\ 200, changeset) do
    conn
    |> put_status(status)
    |> assign(:changeset, changeset)
    |> render("edit.html")
  end

  @spec delete(Plug.Conn.t(), any) :: Plug.Conn.t()
  def delete(conn, _) do
    sender = conn.assigns.sender
    changeset = change({sender, %{delete_confirmation: :string}})
    render_delete(conn, changeset)
  end

  @spec post_delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def post_delete(conn, params) do
    sender = conn.assigns.sender

    changeset =
      change({sender, %{delete_confirmation: :string}})
      |> cast(params["sender"] || %{}, [:delete_confirmation])
      |> validate_required([:delete_confirmation])
      |> validate_inclusion(:delete_confirmation, [sender.name])

    if changeset.valid? do
      Mailings.delete_sender(sender.id)
      redirect(conn, to: Routes.sender_path(conn, :index, conn.assigns.current_project.id))
    else
      {:error, changeset} = apply_action(changeset, :update)
      render_delete(conn, 400, changeset)
    end
  end

  defp render_delete(conn, status \\ 200, changeset) do
    sender = conn.assigns.sender

    conn
    |> put_status(status)
    |> put_meta(:title, gettext("Delete %{sender}", sender: sender.name))
    |> assign(:changeset, changeset)
    |> render("delete.html")
  end

  defp current_project(conn), do: conn.assigns.current_project

  defp authorize(conn, _) do
    project_id = current_project(conn).id
    sender_id = conn.path_params["id"]

    case Mailings.get_project_sender(project_id, sender_id) do
      nil ->
        conn
        |> put_status(404)
        |> halt()

      sender ->
        assign(conn, :sender, sender)
    end
  end
end
