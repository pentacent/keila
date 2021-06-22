defmodule KeilaWeb.SenderController do
  use KeilaWeb, :controller

  alias Keila.{Mailings, Mailings.Sender, Mailings.Sender.Config}
  import Ecto.Changeset

  plug :put_resource
       when action not in [
              :index,
              :new,
              :create,
              :verify_from_token,
              :cancel_verification_from_token
            ]

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    senders = Mailings.get_project_senders(current_project(conn).id)

    conn
    |> assign(:senders, senders)
    |> render("index.html")
  end

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    redirect(conn, to: Routes.sender_path(conn, :edit, project_id(conn), id))
  end

  @spec new(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def new(conn, _) do
    changeset = change(%Sender{}, %{config: change(%Config{}, %{type: "smtp"})})

    conn
    |> render_edit(changeset)
  end

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, %{"sender" => params}) do
    case Mailings.create_sender(project_id(conn), params) do
      {:ok, _} -> redirect(conn, to: Routes.sender_path(conn, :index, project_id(conn)))
      {:error, changeset} -> conn |> put_status(400) |> render_edit(changeset)
    end
  end

  @spec edit(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def edit(conn, _params) do
    conn
    |> render_edit(Ecto.Changeset.change(conn.assigns.sender))
  end

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, params = %{"id" => id}) do
    project = current_project(conn)

    case Mailings.update_sender(id, params["sender"] || %{}) do
      {:ok, _sender} -> redirect(conn, to: Routes.sender_path(conn, :index, project.id))
      {:error, changeset} -> conn |> put_status(400) |> render_edit(changeset)
    end
  end

  @spec delete_confirmation(Plug.Conn.t(), any) :: Plug.Conn.t()
  def delete_confirmation(conn, _) do
    conn
    |> render_delete(change(conn.assigns.sender))
  end

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, params) do
    sender = conn.assigns.sender
    changeset = deletion_changeset(sender, params["sender"] || %{})

    if changeset.valid? do
      Mailings.delete_sender(sender.id)
      redirect(conn, to: Routes.sender_path(conn, :index, conn.assigns.current_project.id))
    else
      {:error, changeset} = apply_action(changeset, :update)
      conn |> put_status(400) |> render_delete(changeset)
    end
  end

  defp deletion_changeset(sender, params) do
    change({sender, %{delete_confirmation: :string}})
    |> cast(params, [:delete_confirmation])
    |> validate_required([:delete_confirmation])
    |> validate_inclusion(:delete_confirmation, [sender.name])
  end

  @spec verify_from_token(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def verify_from_token(conn, %{"token" => token}) do
    case Mailings.verify_sender_from_token(token) do
      {:ok, sender} -> conn |> assign(:sender, sender) |> render("verification_success.html")
      :error -> conn |> put_status(404) |> render("verification_failure.html")
    end
  end

  @spec cancel_verification_from_token(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def cancel_verification_from_token(conn, %{"token" => token}) do
    Keila.Auth.find_and_delete_token("mailings.confirm_sender_email", token)

    conn |> put_status(404) |> render("verification_failure.html")
  end

  defp render_edit(conn, changeset) do
    shared_senders = Mailings.get_shared_senders()

    conn
    |> assign(:changeset, changeset)
    |> assign(:shared_senders, shared_senders)
    |> render("edit.html")
  end

  defp render_delete(conn, changeset) do
    conn
    |> assign(:changeset, changeset)
    |> render("delete.html")
  end

  defp current_project(conn), do: conn.assigns.current_project
  defp project_id(conn), do: conn.assigns.current_project.id

  defp put_resource(conn = %{path_params: %{"id" => id}}, _) do
    project_id = current_project(conn).id

    case Mailings.get_project_sender(project_id, id) do
      nil -> conn |> put_status(404) |> halt()
      sender -> assign(conn, :sender, sender)
    end
  end
end
