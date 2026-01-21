require Keila

Keila.if_cloud do
  defmodule KeilaCloud.Billing do
    @moduledoc """
    Context module for handling Subscriptions and Plans.
    """

    use Keila.Repo
    alias Keila.Accounts.Account
    alias __MODULE__.{Subscription, Plan, Plans}

    @doc """
    Returns `true` if subscriptions are enabled in the application configuration,
    otherwise `false`.
    """
    @spec billing_enabled?() :: boolean()
    def billing_enabled?() do
      Application.get_env(:keila, __MODULE__, []) |> Keyword.get(:enabled) == true
    end

    @doc """
    Returns `Subscription` with given `id`. If it doesn’t exist, returns `nil`.
    """
    @spec get_subscription(Subscription.id()) :: Subscription.t() | nil
    def get_subscription(id) do
      Repo.get(Subscription, id)
    end

    @doc """
    Retrieves `Subscription` associated with `Account` with given `account_id`.
    If no such `Subscription` exists, returns `nil`.
    """
    @spec get_account_subscription(Account.id()) :: Subscription.t() | nil
    def get_account_subscription(account_id) do
      from(s in Subscription, where: s.account_id == ^account_id)
      |> Repo.one()
    end

    @doc """
    Retrieves `Subscription` by its ID from the Paddle API.
    If no such `Subscription` exists, returns `nil`.
    """
    @spec get_subscription_by_paddle_id(String.t()) :: Subscription.t() | nil
    def get_subscription_by_paddle_id(paddle_subscription_id) do
      from(s in Subscription, where: s.paddle_subscription_id == ^paddle_subscription_id)
      |> Repo.one()
    end

    @doc """
    Creates a new `Subscription`
    """
    @spec create_subscription(Account.id(), map()) ::
            {:ok, Subscription.t()} | {:error, Changeset.t(Subscription.t())}
    def create_subscription(account_id, params) do
      params
      |> stringize_params()
      |> Map.put("account_id", account_id)
      |> Subscription.insert_changeset()
      |> Repo.insert()
    end

    @doc """
    Creates a new `Subscription` or updates an existing one if it the `Account`
    specified by `account_id` already has one.
    """
    @spec create_or_update_subscription(Account.id(), map(), boolean()) ::
            {:ok, Subscription.t()} | {:error, Changeset.t(Subscription.t())}
    def create_or_update_subscription(account_id, params, add_credits?) do
      changeset =
        params
        |> stringize_params()
        |> Map.put("account_id", account_id)
        |> Subscription.insert_changeset()

      replace_fields =
        [:paddle_plan_id, :next_billed_on, :status]
        |> then(fn fields ->
          if get_field(changeset, :update_url) do
            fields ++ [:update_url, :cancel_url]
          else
            fields
          end
        end)

      changeset
      |> Repo.insert(
        conflict_target: [:account_id],
        on_conflict: {:replace, replace_fields}
      )
      |> tap(&maybe_add_credits(&1, add_credits?))
    end

    defp maybe_add_credits({:ok, subscription}, true) do
      plan = get_plan(subscription.paddle_plan_id)

      case plan.billing_interval do
        :month ->
          expires_at = DateTime.new!(subscription.next_billed_on, ~T[23:59:00], "Etc/UTC")
          Keila.Accounts.add_credits(subscription.account_id, plan.monthly_credits, expires_at)

        :year ->
          today = Date.utc_today()

          for n <- 0..11 do
            valid_from = today |> Date.shift(month: n) |> DateTime.new!(~T[00:00:00], "Etc/UTC")

            expires_at =
              today |> Date.shift(month: n + 1) |> DateTime.new!(~T[00:00:00], "Etc/UTC")

            Keila.Accounts.add_credits(
              subscription.account_id,
              plan.monthly_credits,
              expires_at,
              valid_from
            )
          end
      end
    end

    defp maybe_add_credits(_, _), do: :ok

    @doc """
    Updates the `Subscription` with given `id`.

    If `add_credits?` is `true` and the update was successful, also adds the
    amount specified as `monthly_credits` from the associated `Plan`.
    """
    @spec update_subscription(Subscription.id(), map()) ::
            {:ok, Subscription.t()} | {:error, Changeset.t(Subscription.t())}
    def update_subscription(id, params, add_credits? \\ false) do
      id
      |> get_subscription()
      |> Subscription.update_changeset(params)
      |> Repo.update()
      |> tap(&maybe_add_credits(&1, add_credits?))
    end

    @doc """
    Cancels `Subscription` with given `id`. In order to remain consistent with the
    Paddle API, this sets the `Subscription`’s `status` attribute to `:deleted`.
    """
    @spec cancel_subscription(Subscription.id()) ::
            {:ok, Subscription.t()} | {:error, Changeset.t(Subscription.t())}
    def cancel_subscription(account_id) do
      account_id
      |> get_subscription()
      |> Subscription.update_changeset(%{status: :deleted})
      |> Repo.update()
    end

    @doc """
    Returns all `Plan`s.
    """
    @spec get_plans() :: [Plan.t()]
    def get_plans() do
      Plans.all() |> Enum.sort_by(& &1.monthly_credits)
    end

    @doc """
    Returns `Plan` by its ID from the Paddle API.
    """
    @spec get_plan(String.t()) :: Plan.t() | nil
    def get_plan(paddle_plan_id) do
      Plans.all()
      |> Enum.find(&(&1.paddle_id == paddle_plan_id))
    end

    defdelegate feature_available?(project_id, feature), to: __MODULE__.Features
  end
end
