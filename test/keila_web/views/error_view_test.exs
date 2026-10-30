defmodule KeilaWeb.ErrorViewTest do
  use KeilaWeb.ConnCase, async: true

  # Bring render/3 and render_to_string/3 for testing custom views
  import Phoenix.View

  test "renders 404.html" do
    assert render_to_string(KeilaWeb.ErrorView, "404.html", []) =~
             "The page you’re trying to access does not exist."
  end

  test "renders 404 page for unknown routes and missing records", %{conn: conn} do
    assert get(conn, "/does-not-exist") |> html_response(404) =~
             "The page you’re trying to access does not exist."

    {404, _headers, body} = assert_error_sent 404, fn -> get(conn, "/archive/nmc_unknown") end
    assert body =~ "The page you’re trying to access does not exist."
  end

  test "renders 500.html" do
    assert render_to_string(KeilaWeb.ErrorView, "500.html", []) =~
             "Please contact your administrator or check the logs."
  end
end
