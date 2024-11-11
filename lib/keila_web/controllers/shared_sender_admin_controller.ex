defmodule KeilaWeb.SharedSenderAdminController do
  use KeilaWeb, :controller
  alias Keila.{Mailings, Mailings.SharedSender, Mailings.Sender.Config, Mailings.SenderAdapters}
  import Ecto.Changeset

  plug :authorize
  plug :put_resource when action not in [:index, :new, :create]

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    shared_senders = Mailings.get_shared_senders()

    conn
    |> assign(:shared_senders, shared_senders)
    |> render("index.html")
  end

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    redirect(conn, to: Routes.shared_sender_admin_path(conn, :edit, id))
  end

  @spec new(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def new(conn, _) do
    changeset =
      %SharedSender{}
      |> change(%{config: change(%Config{}, %{type: "ses"})})

    conn
    |> assign(:changeset, changeset)
    |> put_sender_adapters()
    |> render("edit.html")
  end

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, params) do
    case Mailings.create_shared_sender(params["shared_sender"] || %{}) do
      {:ok, _} ->
        conn
        |> redirect(to: Routes.shared_sender_admin_path(conn, :index))

      {:error, changeset} ->
        conn
        |> put_status(400)
        |> assign(:changeset, changeset)
        |> put_sender_adapters()
        |> render("edit.html")
    end
  end

  @spec edit(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def edit(conn, _params) do
    changeset = change(conn.assigns.shared_sender)

    conn
    |> assign(:changeset, changeset)
    |> put_sender_adapters()
    |> render("edit.html")
  end

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{"shared_sender" => params}) do
    case Mailings.update_shared_sender(conn.assigns.shared_sender.id, params) do
      {:ok, _shared_sender} ->
        redirect(conn, to: Routes.shared_sender_admin_path(conn, :index))

      {:error, changeset} ->
        conn
        |> assign(:changeset, changeset)
        |> put_sender_adapters()
        |> render("edit.html")
    end
  end

  @spec delete_confirmation(Plug.Conn.t(), any) :: Plug.Conn.t()
  def delete_confirmation(conn, _params) do
    changeset = deletion_changeset(conn.assigns.shared_sender, %{})

    conn
    |> assign(:changeset, changeset)
    |> render("delete.html")
  end

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, params) do
    shared_sender = conn.assigns.shared_sender
    changeset = deletion_changeset(shared_sender, params["shared_sender"] || %{})

    if changeset.valid? do
      :ok = Mailings.delete_shared_sender(shared_sender.id)
      redirect(conn, to: Routes.shared_sender_admin_path(conn, :index))
    else
      {:error, changeset} = apply_action(changeset, :update)

      conn
      |> assign(:changeset, changeset)
      |> render("delete.html")
    end
  end

  defp deletion_changeset(shared_sender, params) do
    change({shared_sender, %{delete_confirmation: :string}})
    |> cast(params, [:delete_confirmation])
    |> validate_required([:delete_confirmation])
    |> validate_inclusion(:delete_confirmation, [shared_sender.name])
  end

  defp put_sender_adapters(conn) do
    sender_adapters =
      [
        if(shared_adapter_enabled?(SenderAdapters.Shared.SES), do: SenderAdapters.SES.name()),
        if(shared_adapter_enabled?(SenderAdapters.Shared.Local), do: SenderAdapters.Local.name())
      ]
      |> Enum.filter(& &1)

    assign(conn, :sender_adapters, sender_adapters)
  end

  defp shared_adapter_enabled?(adapter) do
    shared_adapters =
      Application.fetch_env!(:keila, SenderAdapters) |> Keyword.fetch!(:shared_adapters)

    adapter in shared_adapters
  end

  defp authorize(conn = %{assigns: %{is_admin?: true}}, _),
    do: conn

  defp authorize(conn, _),
    do: conn |> put_status(404) |> halt()

  defp put_resource(conn = %{path_params: %{"id" => id}}, _) do
    case Mailings.get_shared_sender(id) do
      nil -> conn |> put_status(404) |> halt()
      shared_sender -> conn |> assign(:shared_sender, shared_sender)
    end
  end
end
