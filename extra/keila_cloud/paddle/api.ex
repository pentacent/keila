require Keila

Keila.if_cloud do
  defmodule KeilaCloud.Paddle.Api do
    @moduledoc """
    Client for the classic Paddle API.
    """

    alias KeilaCloud.Paddle.Transaction

    @default_page_size 12

    @doc """
    Lists transactions for the given Paddle `subscription_id`.

    ## Options
    - `:paginate` - keyword list with `:page` (0-indexed, defaults to `0`) and
      `:page_size` (defaults to `12`).
    """
    @spec list_transactions(String.t(), paginate: keyword()) ::
            {:ok, Keila.Pagination.t(Transaction.t())} | {:error, term()}
    def list_transactions(subscription_id, opts \\ []) do
      page = get_in(opts, [:paginate, :page]) || 0
      page_size = get_in(opts, [:paginate, :page_size]) || @default_page_size

      body =
        [
          subscription_id: subscription_id,
          limit: page_size,
          offset: page * page_size,
          is_paid: true
        ]

      case Req.post(client(), url: "/2.0/subscription/payments", form: body) do
        {:ok, %{status: 200, body: %{"success" => true, "response" => payments} = response}} ->
          {:ok, build_pagination(payments, response, page, page_size)}

        {:ok, %{status: 200, body: %{"success" => false, "error" => error}}} ->
          {:error, {:paddle_api_error, error}}

        {:ok, %{status: status, body: body}} ->
          {:error, {:paddle_api_error, status, body}}

        {:error, reason} ->
          {:error, reason}
      end
    end

    defp build_pagination(payments, response, page, page_size) do
      transactions = Enum.map(payments, &Transaction.from_api/1)
      total = response["total"]
      page_count = if total > 0, do: div(total - 1, page_size) + 1, else: 0

      %Keila.Pagination{
        page: page,
        data: transactions,
        count: total,
        page_count: page_count
      }
    end

    defp client() do
      Req.new(base_url: base_url())
      |> Req.Request.prepend_request_steps(
        auth: fn client ->
          form = Keyword.merge(client.options[:form], auth())
          Req.Request.merge_options(client, form: form)
        end
      )
    end

    defp auth() do
      config = config()
      vendor_id = Keyword.fetch!(config, :paddle_vendor)
      vendor_auth_code = Keyword.fetch!(config, :paddle_api_key)

      [vendor_id: vendor_id, vendor_auth_code: vendor_auth_code]
    end

    defp base_url() do
      case Keyword.fetch!(config(), :paddle_environment) do
        "sandbox" -> "https://sandbox-vendors.paddle.com/api"
        _ -> "https://vendors.paddle.com/api"
      end
    end

    defp config() do
      Application.get_env(:keila, KeilaCloud.Billing)
    end
  end
end
