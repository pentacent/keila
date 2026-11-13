defmodule KeilaWeb.LiveSessionTest do
  use KeilaWeb.ConnCase, async: true
  use KeilaWeb, :verified_routes
  import Phoenix.LiveViewTest

  @tag :live_session
  test "LiveView can't be connected with a saved session after logout", %{conn: conn} do
    {conn, project} = with_login_and_project(conn)
    campaign = insert!(:mailings_campaign, project_id: project.id)
    conn = get(conn, ~p"/projects/#{project.id}/campaigns/#{campaign.id}")

    Keila.Auth.find_and_delete_token(get_session(conn, :token), "web.session")

    assert {:error, {:redirect, %{to: "/auth/login"}}} = live(conn)
  end

  @tag :live_session
  test "LiveView can't be connected with a saved session after losing access to the project",
       %{conn: conn} do
    {conn, project} = with_login_and_project(conn)
    campaign = insert!(:mailings_campaign, project_id: project.id)
    conn = get(conn, ~p"/projects/#{project.id}/campaigns/#{campaign.id}")

    Keila.Auth.remove_user_from_group(conn.assigns.current_user.id, project.group_id)

    assert {%{reason: "reload", status: 404}, _} = catch_exit(live(conn))
  end

  @tag :live_session
  test "LiveView can't be connected with a saved session after the campaign was deleted",
       %{conn: conn} do
    {conn, project} = with_login_and_project(conn)
    campaign = insert!(:mailings_campaign, project_id: project.id)
    conn = get(conn, ~p"/projects/#{project.id}/campaigns/#{campaign.id}")

    Keila.Mailings.delete_campaign(campaign.id)

    assert {%{reason: "reload", status: 404}, _} = catch_exit(live(conn))
  end
end
