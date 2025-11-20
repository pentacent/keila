defmodule KeilaWeb.SenderController do
  use KeilaWeb, :controller

  require Keila
  alias Keila.Mailings
  import Ecto.Changeset
  import Phoenix.LiveView.Controller

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
    Keila.if_cloud do
      live_render(conn, KeilaWeb.CloudSenderCreateLive,
        session: %{
          "current_project_id" => conn.assigns.current_project.id,
          "current_user_id" => conn.assigns.current_user.id,
          "sender_id" => nil,
          "locale" => Gettext.get_locale()
        }
      )
    else
      edit(conn, %{})
    end
  end

  @spec edit(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def edit(conn, _params) do
    live_render(conn, KeilaWeb.SenderEditLive,
      session: %{
        "current_project" => conn.assigns.current_project,
        "current_user" => conn.assigns.current_user,
        "sender_id" => conn.assigns[:sender] && conn.assigns.sender.id,
        "locale" => Gettext.get_locale()
      }
    )
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
    case Mailings.verify_sender_from_email(token) do
      {:ok, sender} ->
        current_user = conn.assigns[:current_user]
        user_projects = if current_user, do: Keila.Projects.get_user_projects(current_user.id)

        if current_user && Enum.any?(user_projects, &(&1.id == sender.project_id)) do
          conn |> redirect(to: Routes.sender_path(conn, :edit, sender.project_id, sender.id))
        else
          conn |> assign(:sender, sender) |> render("verification_success.html")
        end

      :error ->
        conn |> put_status(404) |> render("verification_failure.html")
    end
  end

  @spec cancel_verification_from_token(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def cancel_verification_from_token(conn, %{"token" => token}) do
    Keila.Mailings.cancel_sender_from_email_verification(token)

    conn |> put_status(404) |> render("verification_failure.html")
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
