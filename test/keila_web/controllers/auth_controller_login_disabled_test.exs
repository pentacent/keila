defmodule KeilaWeb.AuthControllerDisabledTest do
  use KeilaWeb.ConnCase, async: false

  setup do
    Application.put_env(:keila, :registration_disabled, true)

    on_exit(fn ->
      Application.put_env(:keila, :registration_disabled, false)
    end)
  end

  @tag :auth_controller
  test "Registration can be disabled", %{conn: conn} do
    conn = get(conn, Routes.auth_path(conn, :register))
    assert html_response(conn, 200) =~ "Registration disabled"

    conn = post(conn, Routes.auth_path(conn, :post_register))
    assert html_response(conn, 200) =~ "Registration disabled"
  end
end
