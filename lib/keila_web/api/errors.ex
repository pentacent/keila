defmodule KeilaWeb.Api.Errors do
  @moduledoc """
  This is a helper module for sending consistent error messages from API
  controllers.
  """

  alias Plug.Conn
  import Plug.Conn
  import Phoenix.Controller

  @spec send_403(Conn.t()) :: Conn.t()
  def send_403(conn) do
    conn
    |> put_status(403)
    |> put_view(KeilaWeb.ApiErrorView)
    |> render("errors.json", %{errors: [[status: 403, title: "Not authorized"]]})
  end

  @spec send_404(Conn.t()) :: Conn.t()
  def send_404(conn) do
    conn
    |> put_status(404)
    |> put_view(KeilaWeb.ApiErrorView)
    |> render("errors.json", %{errors: [[status: 404, title: "Not found"]]})
  end

  @spec send_changeset_error(Conn.t(), Ecto.Changeset.t()) :: Conn.t()
  def send_changeset_error(conn, changeset) do
    conn
    |> put_status(400)
    |> put_view(KeilaWeb.ApiErrorView)
    |> render("errors.json", %{errors: [[status: 400, detail: changeset]]})
  end

  @spec send_open_api_spex_errors(Conn.t(), OpenApiSpex.Error.t()) :: Conn.t()
  def send_open_api_spex_errors(conn, errors) do
    errors = Enum.map(errors, fn error -> [status: 400, detail: error] end)

    conn
    |> put_status(400)
    |> put_view(KeilaWeb.ApiErrorView)
    |> render("errors.json", %{errors: errors})
  end
end
