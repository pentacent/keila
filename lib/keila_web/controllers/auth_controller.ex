defmodule KeilaWeb.AuthController do
  use KeilaWeb, :controller
  alias Keila.Auth

  def register(conn, _params) do
    conn
    |> assign(:changeset, Ecto.Changeset.change(%Auth.User{}))
    |> put_meta(:title, dgettext("auth", "Sign up"))
    |> render("register.html")
  end

  @spec post_register(Plug.Conn.t(), map) :: Plug.Conn.t()
  def post_register(conn, %{"user" => params}) do
    case Auth.create_user(params, &Routes.auth_url(conn, :activate, &1)) do
      {:ok, user} ->
        conn
        |> assign(:user, user)
        |> put_meta(:title, dgettext("auth", "Sign up successful"))
        |> render("register_success.html")

      {:error, changeset} ->
        conn
        |> assign(:changeset, changeset)
        |> put_meta(:title, dgettext("auth", "Sign up"))
        |> put_status(400)
        |> render("register.html")
    end
  end

  def post_register(conn, _), do: post_register(conn, %{"user" => %{}})

  def activate(conn, %{"token" => token}) do
    case Auth.activate_user_from_token(token) do
      {:ok, _user} ->
        # TODO Login
        conn
        |> put_meta(:title, dgettext("auth", "Activation successful"))
        |> render("activate_success.html")

      :error ->
        conn
        |> put_status(404)
        |> put_meta(:title, dgettext("auth", "Activation failed"))
        |> render("activate_failure.html")
    end
  end

  @spec reset(Plug.Conn.t(), map) :: Plug.Conn.t()
  def reset(conn, _params) do
    conn
    |> assign(:changeset, Ecto.Changeset.change(%Auth.User{}))
    |> put_meta(:title, dgettext("auth", "Password reset"))
    |> render("reset.html")
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
        Auth.send_password_reset_link(user.id, &Routes.auth_url(conn, :reset, &1))
      end

      conn
      |> assign(:email, email)
      |> put_meta(:title, dgettext("auth", "Password reset"))
      |> render("reset_success.html")
    else
      conn
      |> assign(:changeset, changeset)
      |> put_status(400)
      |> put_meta(:title, dgettext("auth", "Password reset"))
      |> render("reset.html")
    end
  end

  def post_reset(conn, _), do: post_reset(conn, %{"user" => %{}})
end
