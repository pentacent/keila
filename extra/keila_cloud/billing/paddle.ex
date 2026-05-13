require Keila

Keila.if_cloud do
  defmodule KeilaCloud.Billing.Paddle do
    @moduledoc false

    alias KeilaCloud.Billing
    alias KeilaCloud.Paddle.Api
    alias KeilaCloud.Paddle.Transaction

    @doc """
    Lists transactions for the `Account` with the given `account_id`.

    Looks up the account's `paddle_subscription_id` and delegates to
    `KeilaCloud.Paddle.Api.list_transactions/2`. Accounts with no Paddle
    subscription get an empty `Keila.Pagination`.

    ## Options
    - `:paginate` - keyword list forwarded to
      `KeilaCloud.Paddle.Api.list_transactions/2` (e.g. `[page: 0, page_size: 12]`).
    """
    @spec list_transactions(Keila.Accounts.Account.id(), paginate: keyword()) ::
            {:ok, Keila.Pagination.t(Transaction.t())} | {:error, term()}
    def list_transactions(account_id, opts \\ []) do
      case Billing.get_account_subscription(account_id) do
        %{paddle_subscription_id: subscription_id} when is_binary(subscription_id) ->
          Api.list_transactions(subscription_id, opts)

        _ ->
          {:ok, %Keila.Pagination{page: 0, data: [], count: 0, page_count: 0}}
      end
    end

    @doc """
    Validates the signature of an incoming Paddle webhook. Returns `true` if
    signature is valid, otherwise `false`.

    Signature validation can be disabled for testing purposes with
    `config :keila, KeilaCloud.Billing, paddle_signature_verification_enabled: false`
    """
    @spec valid_signature?(map()) :: boolean()
    def valid_signature?(params) do
      if signature_validation_enabled?() do
        {raw_signature, raw_params} = Map.pop(params, "p_signature", "")
        signature = parse_signature(raw_signature)
        serialized_params = serialize_params(raw_params)

        :public_key.verify(serialized_params, :sha, signature, paddle_key())
      else
        true
      end
    end

    defp signature_validation_enabled?() do
      Application.get_env(:keila, KeilaCloud.Billing)
      |> Keyword.get(:paddle_signature_verification_enabled, true)
    end

    defp parse_signature(raw_signature) do
      case Base.decode64(raw_signature) do
        {:ok, signature} -> signature
        _ -> nil
      end
    end

    defp serialize_params(raw_params) do
      raw_params
      |> Enum.map(fn {key, value} -> {key, to_string(value)} end)
      |> Enum.sort_by(fn {key, _} -> key end)
      |> PhpSerializer.serialize()
    end

    defp paddle_key() do
      paddle_env =
        Application.get_env(:keila, KeilaCloud.Billing)
        |> Keyword.fetch!(:paddle_environment)

      Path.join(:code.priv_dir(:keila), "vendor/paddle/public_key.#{paddle_env}.pem")
      |> File.read!()
      |> :public_key.pem_decode()
      |> then(fn [pem_entry] -> :public_key.pem_entry_decode(pem_entry) end)
    end
  end
end
