defmodule KeilaWeb.WebauthnController do
  use KeilaWeb, :controller
  alias Keila.Auth
  alias KeilaWeb.Router.Helpers, as: Routes

  @spec register_begin(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def register_begin(conn, _params) do
    user_id = conn.assigns.current_user.id
    
    case Auth.start_webauthn_registration(user_id) do
      {:ok, challenge_data} ->
        conn
        |> put_status(200)
        |> json(challenge_data)
        
      {:error, reason} ->
        conn
        |> put_status(400)
        |> json(%{error: reason})
    end
  end

  @spec register_complete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def register_complete(conn, %{"attestation" => attestation}) do
    user_id = conn.assigns.current_user.id
    
    case Auth.complete_webauthn_registration(user_id, attestation) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, dgettext("auth", "Security key has been registered successfully"))
        |> redirect(to: Routes.two_factor_path(conn, :setup))
        
      {:error, reason} ->
        conn
        |> put_flash(:error, dgettext("auth", "Failed to register security key: %{reason}", reason: reason))
        |> redirect(to: Routes.two_factor_path(conn, :setup))
    end
  end

  @spec authenticate_begin(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def authenticate_begin(conn, %{"user_id" => user_id}) do
    case Auth.start_webauthn_authentication(user_id) do
      {:ok, challenge_data} ->
        conn
        |> put_status(200)
        |> json(challenge_data)
        
      {:error, reason} ->
        conn
        |> put_status(400)
        |> json(%{error: reason})
    end
  end

  @spec authenticate_complete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def authenticate_complete(conn, %{"user_id" => user_id, "assertion" => assertion}) do
    case Auth.complete_webauthn_authentication(user_id, assertion) do
      {:ok, user} ->
        import KeilaWeb.AuthSession, only: [start_auth_session: 2]
        
        conn
        |> delete_session(:pending_2fa_user_id)
        |> start_auth_session(user.id)
        |> redirect(to: "/")
        
      {:error, reason} ->
        conn
        |> put_status(400)
        |> json(%{error: reason})
    end
  end

  @spec remove_credential(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def remove_credential(conn, %{"credential_id" => credential_id}) do
    user_id = conn.assigns.current_user.id
    
    case Auth.remove_webauthn_credential(user_id, credential_id) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, dgettext("auth", "Security key has been removed"))
        |> redirect(to: Routes.two_factor_path(conn, :setup))
        
      {:error, reason} ->
        conn
        |> put_flash(:error, dgettext("auth", "Failed to remove security key: %{reason}", reason: reason))
        |> redirect(to: Routes.two_factor_path(conn, :setup))
    end
  end
end
