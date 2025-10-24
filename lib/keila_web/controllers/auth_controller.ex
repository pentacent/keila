defmodule KeilaWeb.AuthController do
  use KeilaWeb, :controller
  alias Keila.Auth

  @spec register(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def register(conn, _params) do
    if Application.get_env(:keila, :registration_disabled, false) do
      render(conn, "registration_disabled.html")
    else
      render_register(conn, user_changeset())
    end
  end

  @spec post_register(Plug.Conn.t(), map) :: Plug.Conn.t()
  def post_register(conn, params) do
    if Application.get_env(:keila, :registration_disabled, false) do
      render(conn, "registration_disabled.html")
    else
      do_post_register(conn, params)
    end
  end

  defp do_post_register(conn, params = %{"user" => user_params}) do
    captcha_response = KeilaWeb.Captcha.get_captcha_response(params)

    if captcha_valid?(captcha_response) do
      case Auth.create_user(user_params, url_fn: &Routes.auth_url(conn, :activate, &1)) do
        {:ok, user} ->
          conn
          |> assign(:user, user)
          |> put_meta(:title, dgettext("auth", "Sign up successful"))
          |> render("register_success.html")

        {:error, changeset} ->
          conn
          |> render_register(400, changeset)
      end
    else
      {:error, changeset} =
        user_params
        |> Auth.User.creation_changeset()
        |> Ecto.Changeset.add_error(:captcha, dgettext("auth", "Please complete the captcha."))
        |> Ecto.Changeset.apply_action(:insert)

      conn
      |> render_register(400, changeset)
    end
  end

  defp do_post_register(conn, _), do: post_register(conn, %{"user" => %{}})

  defp render_register(conn, status \\ 200, changeset) do
    conn
    |> put_status(status)
    |> assign(:changeset, changeset)
    |> put_meta(:title, dgettext("auth", "Sign up"))
    |> render("register.html")
  end

  @spec activate(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def activate(conn, %{"token" => token}) do
    case Auth.activate_user_from_token(token) do
      {:ok, _user} ->
        # TODO Login
        conn
        |> put_meta(:title, dgettext("auth", "Activation successful"))
        |> render("activate_success.html")

      :error ->
        conn
        |> render_404()
    end
  end

  @spec activate_required(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def activate_required(conn, _) do
    conn
    |> put_meta(:title, dgettext("auth", "Activation required"))
    |> render("activate_required.html")
  end

  @spec post_activate_resend(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def post_activate_resend(conn, _) do
    user = conn.assigns.current_user

    if not is_nil(user) and user.activated_at == nil do
      Auth.send_activation_link(user.id, &Routes.auth_url(conn, :activate, &1))
      render(conn, "activate_resend_success.html")
    else
      redirect(conn, to: Routes.auth_path(conn, :login))
    end
  end

  @spec reset(Plug.Conn.t(), map) :: Plug.Conn.t()
  def reset(conn, _params) do
    render_reset(conn, user_changeset())
  end

  @spec post_reset(Plug.Conn.t(), map) :: Plug.Conn.t()
  def post_reset(conn, %{"user" => params}) do
    changeset =
      %Auth.User{}
      |> Ecto.Changeset.cast(params, [:email])
      |> Ecto.Changeset.validate_required([:email])

    if changeset.valid? do
      email = Ecto.Changeset.get_change(changeset, :email)
      user = Auth.find_user_by_email(email)

      if not is_nil(user) do
        Auth.send_password_reset_link(user.id, &Routes.auth_url(conn, :reset_change_password, &1))
      end

      conn
      |> assign(:email, email)
      |> put_meta(:title, dgettext("auth", "Password reset"))
      |> render("reset_success.html")
    else
      render_reset(conn, 400, changeset)
    end
  end

  def post_reset(conn, _), do: post_reset(conn, %{"user" => %{}})

  defp render_reset(conn, status \\ 200, changeset) do
    conn
    |> put_status(status)
    |> assign(:changeset, changeset)
    |> put_meta(:title, dgettext("auth", "Password reset"))
    |> render("reset.html")
  end

  @spec reset_change_password(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def reset_change_password(conn, %{"token" => token_key}) do
    case Auth.find_token(token_key, "auth.reset") do
      nil -> render_404(conn)
      _token -> render_reset_change_password(conn, token_key, user_changeset())
    end
  end

  @spec post_reset_change_password(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def post_reset_change_password(conn, %{"token" => token_key, "user" => params}) do
    with token = %Auth.Token{} <- Auth.find_token(token_key, "auth.reset"),
         {:ok, _user} <- Auth.update_user_password(token.user_id, params) do
      # TODO Implement Login
      Auth.find_and_delete_token(token_key, "auth.reset")

      conn
      |> put_meta(:title, dgettext("auth", "Password reset successful"))
      |> render("reset_change_password_success.html")
    else
      {:error, changeset} -> render_reset_change_password(conn, 400, token_key, changeset)
      _ -> render_404(conn)
    end
  end

  defp render_reset_change_password(conn, status \\ 200, token_key, changeset) do
    conn
    |> put_status(status)
    |> assign(:changeset, changeset)
    |> assign(:token, token_key)
    |> put_meta(:title, dgettext("auth", "Password reset"))
    |> render("reset_change_password.html")
  end

  @spec login(Plug.Conn.t(), any) :: Plug.Conn.t()
  def login(conn, _params) do
    render_login(conn, user_changeset())
  end

  @spec post_login(Plug.Conn.t(), any) :: Plug.Conn.t()
  def post_login(conn, %{"user" => params}) do
    case Auth.find_user_by_credentials(params) do
      {:ok, user} -> 
        if user.two_factor_enabled || length(user.webauthn_credentials) > 0 do
          conn
          |> put_session(:pending_2fa_user_id, user.id)
          |> redirect(to: Routes.two_factor_path(conn, :challenge))
        else
          do_login(conn, user)
        end
      {:error, changeset} -> render_login(conn, 400, changeset)
    end
  end

  def post_login(conn, _), do: post_login(conn, %{"user" => %{}})

  defp render_login(conn, status \\ 200, changeset) do
    conn
    |> put_status(status)
    |> assign(:changeset, changeset)
    |> put_meta(:title, dgettext("auth", "Sign in"))
    |> render("login.html")
  end

  defp do_login(conn, user) do
    conn
    |> start_auth_session(user.id)
    |> redirect(to: "/")
  end

  @spec logout(Plug.Conn.t(), map) :: Plug.Conn.t()
  def logout(conn, _params) do
    conn
    |> end_auth_session()
    |> redirect(to: Routes.auth_path(conn, :login))
  end

  defp render_404(conn) do
    conn
    |> put_status(404)
    |> put_meta(:title, dgettext("auth", "Not found"))
    |> render("404.html")
  end

  defp user_changeset() do
    Ecto.Changeset.change(%Auth.User{})
  end
end
