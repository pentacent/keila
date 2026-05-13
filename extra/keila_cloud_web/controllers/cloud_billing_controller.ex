require Keila

Keila.if_cloud do
  defmodule KeilaWeb.CloudBillingController do
    use KeilaWeb, :controller
    require Logger

    alias KeilaCloud.Billing.Paddle

    def index(conn, params) do
      page = String.to_integer(Map.get(params, "page", "1")) - 1

      conn
      |> maybe_put_transactions(page)
      |> put_meta(:title, dgettext("cloud", "Billing"))
      |> render("index.html")
    end

    defp maybe_put_transactions(conn, page) do
      case Paddle.list_transactions(conn.assigns.current_account.id, paginate: [page: page]) do
        {:ok, transactions} ->
          conn |> assign(:transactions, transactions) |> assign(:error, false)

        {:error, reason} ->
          Logger.warning("Failed to list Paddle transactions: #{inspect(reason)}")
          conn |> assign(:transactions, nil) |> assign(:error, true)
      end
    end
  end
end
