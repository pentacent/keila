defmodule KeilaWeb.UserAdminController do
  use KeilaWeb, :controller
  alias Keila.{Auth, Accounts, Admin}
  import Phoenix.LiveView.Controller

  plug :authorize

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, params) do
    page = String.to_integer(Map.get(params, "page", "1")) - 1
    users = Auth.list_users(paginate: [page: page, page_size: 20])
    user_accounts = get_user_accounts(users.data)
    user_credits = maybe_get_user_credits(user_accounts)

    conn
    |> put_meta(:title, dgettext("admin", "Administrate Users"))
    |> assign(:users, users)
    |> assign(:user_credits, user_credits)
    |> assign(:user_accounts, user_accounts)
    |> render("index.html")
  end

  defp get_user_accounts(users) do
    users
    |> Enum.map(fn user ->
      account = Accounts.get_user_account(user.id)
      {user.id, account}
    end)
    |> Enum.into(%{})
  end

  defp maybe_get_user_credits(user_accounts) do
    if Accounts.credits_enabled?() do
      user_accounts
      |> Enum.map(fn {user_id, account} ->
        credits = Accounts.get_credits(account.id)
        {user_id, credits}
      end)
      |> Enum.into(%{})
    end
  end

  @spec new(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def new(conn, _) do
    live_render(conn, KeilaWeb.CreateUserLive)
  end

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, %{"user" => user_params}) do
    case Auth.create_user(user_params, url_fn: &Routes.auth_url(conn, :activate, &1)) do
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

  @spec edit(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def edit(conn, %{"id" => user_id}) do
    user = Auth.get_user(user_id)
    changeset = Auth.User.admin_update_changeset(user, %{})

    conn
    |> put_meta(:title, dgettext("admin", "Edit User"))
    |> assign(:user, user)
    |> assign(:changeset, changeset)
    |> render("edit.html")
  end

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{"id" => user_id, "user" => user_params}) do
    # Convert activation status string to proper DateTime value
    processed_params = process_activation_status(user_params)
    
    case Auth.admin_update_user(user_id, processed_params) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, dgettext("admin", "User updated successfully"))
        |> redirect(to: Routes.user_admin_path(conn, :index))

      {:error, %Ecto.Changeset{} = changeset} ->
        user = Auth.get_user(user_id)
        
        conn
        |> put_flash(:error, dgettext("admin", "Could not update user"))
        |> put_meta(:title, dgettext("admin", "Edit User"))
        |> assign(:user, user)
        |> assign(:changeset, changeset)
        |> render("edit.html")
    end
  end

  defp process_activation_status(user_params) do
    case Map.get(user_params, "activated_at") do
      "activated" ->
        Map.put(user_params, "activated_at", DateTime.utc_now() |> DateTime.truncate(:second))
      "not_activated" ->
        Map.put(user_params, "activated_at", nil)
      _ ->
        user_params
    end
  end

  @spec activate(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def activate(conn, %{"id" => user_id}) do
    case Auth.activate_user(user_id) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, dgettext("admin", "User account has been activated"))
        |> redirect(to: Routes.user_admin_path(conn, :index))

      :error ->
        conn
        |> put_flash(:error, dgettext("admin", "Could not activate user account"))
        |> redirect(to: Routes.user_admin_path(conn, :index))
    end
  end

  @spec deactivate(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def deactivate(conn, %{"id" => user_id}) do
    case Auth.deactivate_user(user_id) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, dgettext("admin", "User account has been deactivated"))
        |> redirect(to: Routes.user_admin_path(conn, :index))

      :error ->
        conn
        |> put_flash(:error, dgettext("admin", "Could not deactivate user account"))
        |> redirect(to: Routes.user_admin_path(conn, :index))
    end
  end

  @spec enable_2fa(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def enable_2fa(conn, %{"id" => user_id}) do
    case Auth.enable_two_factor_auth(user_id) do
      {:ok, updated_user} ->
        conn
        |> put_flash(:info, dgettext("admin", "Two-factor authentication has been enabled for this user"))
        |> assign(:user, updated_user)
        |> assign(:backup_codes, updated_user.two_factor_backup_codes)
        |> put_meta(:title, dgettext("admin", "Two-Factor Authentication Enabled"))
        |> render("backup_codes.html")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, dgettext("admin", "Could not enable two-factor authentication"))
        |> redirect(to: Routes.user_admin_path(conn, :edit, user_id))
    end
  end

  @spec disable_2fa(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def disable_2fa(conn, %{"id" => user_id}) do
    case Auth.disable_two_factor_auth(user_id) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, dgettext("admin", "Two-factor authentication has been disabled for this user"))
        |> redirect(to: Routes.user_admin_path(conn, :edit, user_id))

      {:error, _changeset} ->
        conn
        |> put_flash(:error, dgettext("admin", "Could not disable two-factor authentication"))
        |> redirect(to: Routes.user_admin_path(conn, :edit, user_id))
    end
  end

  @spec update_password(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update_password(conn, %{"id" => user_id, "password" => password}) do
    case Auth.update_user_password(user_id, %{password: password}) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, dgettext("admin", "Password has been updated successfully"))
        |> redirect(to: Routes.user_admin_path(conn, :edit, user_id))

      {:error, _changeset} ->
        conn
        |> put_flash(:error, dgettext("admin", "Could not update password"))
        |> redirect(to: Routes.user_admin_path(conn, :edit, user_id))
    end
  end

  @spec send_password_reset(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def send_password_reset(conn, %{"id" => user_id}) do
    user = Auth.get_user(user_id)
    if user do
      :ok = Auth.send_password_reset_link(user_id, &Routes.auth_url(conn, :reset_change_password, &1))
      conn
      |> put_flash(:info, dgettext("admin", "Password reset email has been sent to %{email}", email: user.email))
      |> redirect(to: Routes.user_admin_path(conn, :edit, user_id))
    else
      conn
      |> put_flash(:error, dgettext("admin", "User not found"))
      |> redirect(to: Routes.user_admin_path(conn, :edit, user_id))
    end
  end

  @spec remove_webauthn_key(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def remove_webauthn_key(conn, %{"id" => user_id, "credential_id" => credential_id}) do
    case Auth.remove_webauthn_credential(user_id, credential_id) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, dgettext("admin", "Security key removed successfully."))
        |> redirect(to: Routes.user_admin_path(conn, :edit, user_id))
      
      {:error, _changeset} ->
        conn
        |> put_flash(:error, dgettext("admin", "Failed to remove security key."))
        |> redirect(to: Routes.user_admin_path(conn, :edit, user_id))
    end
  end

  @spec disable_all_webauthn(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def disable_all_webauthn(conn, %{"id" => user_id}) do
    case Auth.remove_all_webauthn_credentials(user_id) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, dgettext("admin", "All security keys removed successfully."))
        |> redirect(to: Routes.user_admin_path(conn, :edit, user_id))
      
      {:error, _changeset} ->
        conn
        |> put_flash(:error, dgettext("admin", "Failed to remove security keys."))
        |> redirect(to: Routes.user_admin_path(conn, :edit, user_id))
    end
  end

  defp authorize(conn, _) do
    case conn.assigns.is_admin? do
      true -> conn
      false -> conn |> put_status(404) |> halt()
    end
  end
end
