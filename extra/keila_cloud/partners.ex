require Keila

Keila.if_cloud do
  defmodule KeilaCloud.Partners do
    @moduledoc """
    Partner mode for Keila Cloud.

    A *partner* Account manages a set of *child* Accounts.
    The partner can transfer credits manually and configure per-child monthly allocations that are
    auto-distributed when the partner's subscription renews.
    """

    use Keila.Repo
    require Logger

    alias Keila.Accounts
    alias Keila.Accounts.Account
    alias Keila.Accounts.CreditTransaction
    alias KeilaCloud.Accounts.Account, as: CloudAccount
    alias KeilaCloud.Partners.PartnerSettings
    alias Keila.Auth

    @doc """
    Creates a new User and Account, makes the Account a child of the partner,
    and marks the User as activated and the Account as `:active`.
    """
    def create_child_account_user(partner_account_id, params, opts \\ []) do
      Repo.transaction(fn ->
        with {:ok, user} <- Auth.create_user(params, skip_activation_email: true),
             {:ok, user} <- Auth.activate_user(user.id),
             account = %Account{} <- Accounts.get_user_account(user.id),
             _account <- Accounts.set_parent_account(account.id, partner_account_id),
             {:ok, account} <- KeilaCloud.Accounts.update_account_status(account.id, :active) do
          %{user: user, account: account}
        else
          {:error, reason} -> Repo.rollback(reason)
        end
      end)
    end

    @doc """
    Updates the password of a User belonging to a child Account of the partner.

    Returns `{:error, :not_a_child}` if the User does not belong to a child
    Account of the given partner.
    """
    def update_child_account_user_password(partner_account_id, child_user_id, params) do
      with :ok <- check_user_managed_by_partner(partner_account_id, child_user_id) do
        Keila.Auth.update_user_password(child_user_id, params)
      end
    end

    defp check_user_managed_by_partner(partner_account_id, user_id) do
      case Accounts.get_user_account(user_id) do
        %Account{id: child_account_id} ->
          check_account_managed_by_partner(partner_account_id, child_account_id)

        _ ->
          {:error, :not_a_child}
      end
    end

    @doc """
    Sets the `is_partner` flag on the given Account.
    """
    def set_is_partner(account_id, is_partner? \\ true) do
      account_id
      |> Accounts.get_account()
      |> CloudAccount.is_partner_changeset(is_partner?)
      |> Repo.update()
    end

    @doc """
    Updates a partner Account's `partner_settings` and reconciles credit
    distribution for any future cycles.
    """
    def update_partner_settings(account_id, params) do
      account_id
      |> Accounts.get_account()
      |> CloudAccount.partner_settings_changeset(params)
      |> Repo.update()
      |> case do
        {:ok, account} ->
          :ok = distribute_partner_credits(account.id)
          {:ok, account}

        error ->
          error
      end
    end

    @doc """
    Transfers `amount` credits from a partner Account to one of its child
    Accounts.

    The child's credits inherit the `expires_at` of the partner's source
    cycles (earliest-expiring first). This prevents partners from laundering
    near-expiry credits into long-lived ones.

    Returns `{:error, :not_a_child}` if the target Account is not a child of
    the given partner, or `{:error, :insufficient_credits}` if the partner
    does not have enough available credits.
    """
    def transfer_credits(partner_account_id, child_account_id, amount) do
      with :ok <- check_account_managed_by_partner(partner_account_id, child_account_id) do
        from(c in CreditTransaction,
          where: c.account_id == ^partner_account_id,
          where: c.expires_at >= fragment("NOW()"),
          where: is_nil(c.valid_from) or c.valid_from <= fragment("NOW()"),
          group_by: c.expires_at,
          order_by: c.expires_at,
          select: {c.expires_at, sum(c.amount)}
        )
        |> Repo.all()
        |> build_transfer_transactions(partner_account_id, child_account_id, amount)
        |> maybe_insert_transfer_transactions()
      end
    end

    defp build_transfer_transactions(amount_tuples, partner_account_id, child_account_id, amount) do
      Enum.reduce_while(amount_tuples, {amount, []}, fn amount_tuple, acc ->
        do_build_transfer_transactions(amount_tuple, partner_account_id, child_account_id, acc)
      end)
    end

    defp do_build_transfer_transactions({_, 0}, _, _, acc), do: {:cont, acc}

    defp do_build_transfer_transactions(
           {expires_at, available_amount},
           partner_account_id,
           child_account_id,
           {remaining_amount, transactions}
         ) do
      transfer_amount = min(available_amount, remaining_amount)
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      new_transactions = [
        %{account_id: partner_account_id, amount: -transfer_amount, expires_at: expires_at, inserted_at: now},
        %{account_id: child_account_id, amount: transfer_amount, expires_at: expires_at, inserted_at: now}
      ]

      case remaining_amount - transfer_amount do
        0 -> {:halt, {0, new_transactions ++ transactions}}
        n -> {:cont, {n, new_transactions ++ transactions}}
      end
    end

    defp maybe_insert_transfer_transactions({0, transactions}) do
      Repo.insert_all(CreditTransaction, transactions)
      :ok
    end

    defp maybe_insert_transfer_transactions(_), do: {:error, :insufficient_credits}

    @doc """
    Distributes a single partner credit cycle to its child Accounts according
    to `partner_settings.credit_allocations`. Replaces any prior distribution
    for the same `(valid_from, expires_at)` window.
    """
    def distribute_partner_transaction_credits(partner_account_id, expires_at, valid_from \\ nil) do
      partner_account_id
      |> Accounts.get_account()
      |> credit_allocations()
      |> case do
        allocations when map_size(allocations) == 0 ->
          :ok

        allocations ->
          Repo.transaction(fn ->
            clear_partner_credit_distribution(partner_account_id, expires_at, valid_from)

            total = allocations |> Map.values() |> Enum.sum()

            if cycle_balance(partner_account_id, expires_at, valid_from) >= total do
              Enum.each(allocations, fn {child_account_id, credits} ->
                distribute_partner_credit_allocation(
                  partner_account_id,
                  child_account_id,
                  credits,
                  expires_at,
                  valid_from
                )
              end)
            else
              Logger.warning(
                "Skipped partner credit distribution for #{inspect(partner_account_id)}: allocations exceed cycle balance"
              )
            end
          end)

          :ok
      end
    end

    defp clear_partner_credit_distribution(_partner_account_id, _expires_at, nil), do: :ok

    defp clear_partner_credit_distribution(partner_account_id, expires_at, valid_from) do
      expires_at = DateTime.truncate(expires_at, :second)
      valid_from = DateTime.truncate(valid_from, :second)

      child_query =
        from c in CreditTransaction,
          join: a in Account,
          on: a.id == c.account_id,
          where: a.parent_id == ^partner_account_id,
          where: c.expires_at == ^expires_at,
          where: c.valid_from == ^valid_from,
          where: c.amount > 0

      partner_query =
        from c in CreditTransaction,
          where: c.account_id == ^partner_account_id,
          where: c.expires_at == ^expires_at,
          where: c.valid_from == ^valid_from,
          where: c.amount < 0

      Repo.delete_all(child_query)
      Repo.delete_all(partner_query)
    end

    defp distribute_partner_credit_allocation(_, _, amount, _, _) when amount <= 0, do: :ok

    defp distribute_partner_credit_allocation(
           partner_account_id,
           child_account_id,
           amount,
           expires_at,
           valid_from
         ) do
      case check_account_managed_by_partner(partner_account_id, child_account_id) do
        :ok ->
          insert_credit_transaction!(partner_account_id, -amount, expires_at, valid_from)
          insert_credit_transaction!(child_account_id, amount, expires_at, valid_from)
          :ok

        {:error, reason} ->
          Logger.warning(
            "Skipped partner credit distribution to #{inspect(child_account_id)}: #{inspect(reason)}"
          )

          :ok
      end
    end

    defp cycle_balance(account_id, expires_at, valid_from) do
      expires_at = DateTime.truncate(expires_at, :second)

      query =
        from c in CreditTransaction,
          where: c.account_id == ^account_id,
          where: c.expires_at == ^expires_at,
          select: sum(c.amount)

      query =
        case valid_from do
          nil ->
            from c in query, where: is_nil(c.valid_from)

          valid_from ->
            from c in query,
              where: c.valid_from == ^DateTime.truncate(valid_from, :second)
        end

      Repo.one(query) || 0
    end

    defp insert_credit_transaction!(account_id, amount, expires_at, valid_from) do
      %{
        account_id: account_id,
        amount: amount,
        expires_at: DateTime.truncate(expires_at, :second),
        valid_from: valid_from && DateTime.truncate(valid_from, :second)
      }
      |> CreditTransaction.changeset()
      |> Repo.insert!()
    end

    @doc """
    Reconciles credit distribution for all future cycles of a partner Account.

    Iterates over the partner's `CreditTransaction`s with `valid_from` in the
    future, wiping the matching child rows and re-creating them from current
    `partner_settings`. Past and current cycles are never touched.
    """
    def distribute_partner_credits(partner_account_id) do
      account = Accounts.get_account(partner_account_id)

      if account && account.is_partner do
        for transaction <- future_partner_credit_transactions(partner_account_id) do
          distribute_partner_transaction_credits(
            partner_account_id,
            transaction.expires_at,
            transaction.valid_from
          )
        end
      end

      :ok
    end

    defp future_partner_credit_transactions(partner_account_id) do
      Repo.all(
        from c in CreditTransaction,
          where: c.account_id == ^partner_account_id,
          where: c.amount > 0,
          where: not is_nil(c.valid_from) and c.valid_from > fragment("NOW()")
      )
    end

    @doc """
    Returns a subquery that resolves to the credit-pool parent for the given
    Account, used by `Keila.Accounts.credits_for_account/1` to decide whether
    a child Account inherits credits from its parent. Children of partner
    Accounts have isolated credit pools and do not inherit.
    """
    def parent_credit_account_id_query(account_id) do
      from a in Account,
        left_join: p in Account,
        on: p.id == a.parent_id,
        where: a.id == ^account_id and (is_nil(p.id) or not p.is_partner),
        select: a.parent_id
    end

    @doc """
    Returns the child Accounts of a partner Account.

    Accepts the same `:paginate` option as `Keila.Auth.list_users/1`.
    """
    def list_partner_child_accounts(partner_account_id, opts \\ []) do
      query =
        from a in Account,
          where: a.parent_id == ^partner_account_id,
          order_by: a.inserted_at

      case Keyword.get(opts, :paginate) do
        nil ->
          Repo.all(query)

        true ->
          Keila.Pagination.paginate(query)

        paginate_opts when is_list(paginate_opts) ->
          Keila.Pagination.paginate(query, paginate_opts)
      end
    end

    @doc """
    Returns `true` if `user_id` belongs to a child of the given partner Account.
    """
    def partner_of?(partner_account_id, user_id) do
      partner = Keila.Accounts.get_account(partner_account_id)
      user_account = Keila.Accounts.get_user_account(user_id)

      !!(partner && partner.is_partner && user_account &&
           user_account.parent_id == partner_account_id)
    end

    @doc """
    Updates a single child Account's credit allocation in the partner's
    `partner_settings`, preserving all other allocations. Triggers
    reconciliation of future cycles via `update_partner_settings/2`.
    """
    def update_credit_allocation(partner_account_id, child_account_id, credits) do
      with :ok <- check_account_managed_by_partner(partner_account_id, child_account_id) do
        updated_allocations =
          partner_account_id
          |> partner_credit_allocations()
          |> Map.put(child_account_id, credits)

        update_partner_settings(partner_account_id, %{"credit_allocations" => updated_allocations})
      end
    end

    @doc """
    Projects the partner's *next* credit cycle from `partner_settings` and the
    active subscription's plan. Returns `nil` when the Account is not a partner
    or has no active subscription.
    """
    def project_partner_next_cycle(partner_account_id) do
      account = Accounts.get_account(partner_account_id)

      with true <- !!(account && account.is_partner),
           subscription when not is_nil(subscription) <-
             KeilaCloud.Billing.get_account_subscription(partner_account_id),
           plan when not is_nil(plan) <-
             KeilaCloud.Billing.get_plan(subscription.paddle_plan_id) do
        allocations = credit_allocations(account)
        allocated = allocations |> Map.values() |> Enum.sum()

        %{
          total: plan.monthly_credits,
          allocated: allocated,
          remaining: plan.monthly_credits - allocated,
          allocations: allocations
        }
      else
        _ -> nil
      end
    end

    @doc """
    Returns the partner's credit allocations as a map of
    `child_account_id => credits`, or `%{}` if the Account is not a partner
    or has no settings.
    """
    def partner_credit_allocations(account_id) do
      account_id |> Accounts.get_account() |> credit_allocations()
    end

    defp credit_allocations(%Account{
           is_partner: true,
           partner_settings: %PartnerSettings{credit_allocations: allocations}
         })
         when is_map(allocations),
         do: allocations

    defp credit_allocations(_), do: %{}

    defp check_account_managed_by_partner(partner_account_id, child_account_id) do
      query =
        from a in Account,
          join: p in Account,
          on: p.id == a.parent_id,
          where: a.id == ^child_account_id and p.id == ^partner_account_id and p.is_partner

      if Repo.exists?(query), do: :ok, else: {:error, :not_a_child}
    end
  end
end
