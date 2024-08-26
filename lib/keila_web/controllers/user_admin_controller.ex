defmodule KeilaWeb.UserAdminController do
  use KeilaWeb, :controller
  alias Keila.{Auth, Accounts, Admin}
  import Phoenix.LiveView.Controller

  plug :authorize

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, params) do
    page = String.to_integer(Map.get(params, "page", "1")) - 1
    users = Auth.list_users(paginate: [page: page, page_size: 20])
    user_credits = maybe_get_user_credits(users.data)

    conn
    |> put_meta(:title, dgettext("admin", "Administrate Users"))
    |> assign(:users, users)
    |> assign(:user_credits, user_credits)
    |> render("index.html")
  end

  defp maybe_get_user_credits(users) do
    if Accounts.credits_enabled?() do
      users
      |> Enum.map(fn user ->
        account = Accounts.get_user_account(user.id)
        credits = Accounts.get_credits(account.id)
        {user.id, credits}
      end)
      |> Enum.into(%{})
    end
  end

  @spec new(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def new(conn, _) do
    conn
    |> render("new.html", changeset: %Plug.Conn{})
  end

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, %{"user" => user_params}) do
    case Auth.create_user(user_params) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, gettext("User created successfully"))
        |> redirect(to: "/admin/users")

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_flash(:error, gettext("Could not create user"))
        |> render("new.html", changeset: changeset)
    end
  end

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, params) do
    ids =
      case get_in(params, ["user", "id"]) do
        ids when is_list(ids) -> ids
        id when is_binary(id) -> [id]
      end

    case get_in(params, ["user", "require_confirmation"]) do
      "true" ->
        render_delete_confirmation(conn, ids)

      _ ->
        Enum.each(ids, fn id -> :ok = Admin.purge_user(id) end)
        redirect(conn, to: Routes.user_admin_path(conn, :index))
    end
  end

  defp render_delete_confirmation(conn, ids) do
    users =
      ids
      |> Enum.filter(&(&1 != conn.assigns.current_user.id))
      |> Enum.map(&Keila.Repo.get(Auth.User, &1))

    conn
    |> put_meta(:title, gettext("Confirm User Deletion"))
    |> assign(:users, users)
    |> render("delete.html")
  end

  @spec show_credits(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show_credits(conn, %{"id" => user_id}) do
    user = Keila.Auth.get_user(user_id)
    account = Keila.Accounts.get_user_account(user.id)
    credits = Keila.Accounts.get_credits(account.id)

    conn
    |> assign(:user, user)
    |> assign(:account, account)
    |> assign(:credits, credits)
    |> render("show_credits.html")
  end

  def create_credits(conn, %{"id" => user_id, "credits" => params}) do
    user = Keila.Auth.get_user(user_id)
    account = Keila.Accounts.get_user_account(user.id)

    amount = String.to_integer(params["amount"])

    with expires_at_params <- params["expires_at"],
         {:ok, date} <- Date.from_iso8601(expires_at_params["date"]),
         {:ok, time} <- Time.from_iso8601(expires_at_params["time"] <> ":00"),
         {:ok, datetime} <- DateTime.new(date, time, expires_at_params["timezone"]),
         {:ok, expires_at} <- DateTime.shift_zone(datetime, "Etc/UTC") do
      Keila.Accounts.add_credits(account.id, amount, expires_at)
      expires_at
    else
      _ -> nil
    end

    redirect(conn, to: Routes.user_admin_path(conn, :show_credits, user.id))
  end

  def impersonate(conn, %{"id" => user_id}) do
    conn
    |> KeilaWeb.AuthSession.end_auth_session()
    |> KeilaWeb.AuthSession.start_auth_session(user_id)
    |> redirect(to: "/")
  end

  defp authorize(conn, _) do
    case conn.assigns.is_admin? do
      true -> conn
      false -> conn |> put_status(404) |> halt()
    end
  end
end
