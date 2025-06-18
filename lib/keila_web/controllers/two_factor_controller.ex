defmodule KeilaWeb.TwoFactorController do
  use KeilaWeb, :controller
  alias Keila.Auth
  alias KeilaWeb.Router.Helpers, as: Routes
  import KeilaWeb.AuthSession, only: [start_auth_session: 2]

  @spec setup(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def setup(conn, _params) do
    user = conn.assigns.current_user
    
    conn
    |> put_meta(:title, dgettext("auth", "Two-Factor Authentication"))
    |> assign(:user, user)
    |> assign(:changeset, Ecto.Changeset.change(user))
    |> render("setup.html")
  end

  @spec enable(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def enable(conn, _params) do
    user_id = conn.assigns.current_user.id
    
    case Auth.enable_two_factor_auth(user_id) do
      {:ok, updated_user} ->
        conn
        |> put_flash(:info, dgettext("auth", "Two-factor authentication has been enabled."))
        |> assign(:user, updated_user)
        |> assign(:backup_codes, updated_user.two_factor_backup_codes)
        |> put_meta(:title, dgettext("auth", "Backup Codes"))
        |> render("backup_codes.html")
      
      {:error, _changeset} ->
        conn
        |> put_flash(:error, dgettext("auth", "Failed to enable two-factor authentication."))
        |> redirect(to: Routes.two_factor_path(conn, :setup))
    end
  end

  @spec disable(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def disable(conn, _params) do
    user_id = conn.assigns.current_user.id
    
    case Auth.disable_two_factor_auth(user_id) do
      {:ok, _updated_user} ->
        conn
        |> put_flash(:info, dgettext("auth", "Two-factor authentication has been disabled."))
        |> redirect(to: Routes.two_factor_path(conn, :setup))
      
      {:error, _changeset} ->
        conn
        |> put_flash(:error, dgettext("auth", "Failed to disable two-factor authentication."))
        |> redirect(to: Routes.two_factor_path(conn, :setup))
    end
  end

  @spec challenge(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def challenge(conn, _params) do
    user_id = get_session(conn, :pending_2fa_user_id)
    
    if user_id do
      user = Auth.get_user(user_id)
      {:ok, _code} = Auth.send_two_factor_code(user_id)
      
      conn
      |> put_flash(:info, dgettext("auth", "A verification code has been sent to your email."))
      |> put_meta(:title, dgettext("auth", "Two-Factor Authentication"))
      |> assign(:user, user)
      |> assign(:changeset, %Ecto.Changeset{data: %{code: nil}})
      |> render("challenge.html")
    else
      conn
      |> redirect(to: Routes.auth_path(conn, :login))
    end
  end

  @spec verify(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def verify(conn, %{"two_factor" => %{"code" => code}}) do
    user_id = get_session(conn, :pending_2fa_user_id)
    
    if user_id do
      case Auth.verify_two_factor_code(user_id, code) do
        {:ok, user} ->
          conn
          |> delete_session(:pending_2fa_user_id)
          |> start_auth_session(user.id)
          |> redirect(to: "/")
        
        :error ->
          user = Auth.get_user(user_id)
          changeset = 
            %Ecto.Changeset{data: %{code: code}}
            |> Ecto.Changeset.add_error(:code, dgettext("auth", "Invalid verification code"))
          
          conn
          |> put_status(400)
          |> put_meta(:title, dgettext("auth", "Two-Factor Authentication"))
          |> assign(:user, user)
          |> assign(:changeset, changeset)
          |> render("challenge.html")
      end
    else
      conn
      |> redirect(to: Routes.auth_path(conn, :login))
    end
  end

  def verify(conn, _params) do
    verify(conn, %{"two_factor" => %{"code" => ""}})
  end

  @spec resend_code(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def resend_code(conn, _params) do
    user_id = get_session(conn, :pending_2fa_user_id)
    
    if user_id do
      case Auth.send_two_factor_code(user_id) do
        {:ok, _code} ->
          conn
          |> put_flash(:info, dgettext("auth", "A new verification code has been sent to your email."))
          |> redirect(to: Routes.two_factor_path(conn, :challenge))
        
        :error ->
          conn
          |> put_flash(:error, dgettext("auth", "Failed to send verification code."))
          |> redirect(to: Routes.auth_path(conn, :login))
      end
    else
      conn
      |> redirect(to: Routes.auth_path(conn, :login))
    end
  end
end
