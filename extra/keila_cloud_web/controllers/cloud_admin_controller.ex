require Keila

Keila.if_cloud do
  defmodule KeilaWeb.CloudAdminController do
    use KeilaWeb, :controller

    plug :authorize

    def show_user_account_status(conn, %{"id" => user_id}) do
      user = Keila.Auth.get_user(user_id)
      account = Keila.Accounts.get_user_account(user.id)
      account_changeset = Ecto.Changeset.change(account, %{})

      conn
      |> assign(:user, user)
      |> assign(:account, account)
      |> assign(:account_changeset, account_changeset)
      |> render("user_account_status.html")
    end

    def update_user_account_status(conn, %{"id" => user_id, "account" => %{"status" => status}}) do
      user = Keila.Auth.get_user(user_id)
      account = Keila.Accounts.get_user_account(user.id)

      {:ok, account} = KeilaCloud.Accounts.update_account_status(account.id, status)
      account_changeset = Ecto.Changeset.change(account, %{})

      conn
      |> assign(:user, user)
      |> assign(:account, account)
      |> assign(:account_changeset, account_changeset)
      |> render("user_account_status.html")
    end

    defp authorize(conn, _) do
      case conn.assigns.is_admin? do
        true -> conn
        false -> conn |> put_status(404) |> halt()
      end
    end
  end
end
