defmodule Keila.Accounts do
  @moduledoc """
  Accounts are a layer for organizing Users built on top of `Keila.Auth.Group`.

  A User can belong to at most one Account while one Account can include several
  Users.

  Accounts are used to enable groups of users to work on shared projects,
  implement sending quotas, or billing.

  Since Accounts are the basis for implementing sending quotas, this module
  also includes functions for managing the quota credit ledger.
  """

  use Keila.Repo
  alias __MODULE__.{Account, CreditTransaction}
  alias Keila.Auth

  @doc """
  Creates a new Account.
  """
  @spec create_account() :: {:ok, Account.t()}
  def create_account() do
    Repo.transaction(fn ->
      {:ok, group} = Auth.create_group(%{parent_id: Auth.root_group().id})
      Repo.insert!(%Account{group_id: group.id}, returning: true)
    end)
  end

  @doc """
  Retrieves Account with the given `account_id`.
  """
  @spec get_account(Account.id()) :: Account.t() | nil
  def get_account(account_id) do
    Repo.get(Account, account_id)
  end

  @doc """
  Returns list of `User`s associated with the `Account` specified by
  `account_id`.
  """
  @spec list_account_users(Account.id()) :: [Auth.User.t()]
  def list_account_users(account_id) when is_id(account_id) do
    account = get_account(account_id)
    Auth.list_group_users(account.group_id)
  end

  @doc """
  Returns `Account` associated with `User` specified by `user_id`.
  """
  @spec get_user_account(Auth.User.id()) :: Account.t() | nil
  def get_user_account(user_id) when is_id(user_id) do
    from(a in Account)
    |> join(:inner, [a], g in Auth.Group, on: g.id == a.group_id)
    |> join(:inner, [a, g], ug in Auth.UserGroup, on: ug.group_id == g.id)
    |> join(:inner, [a, g, ug], u in Auth.User, on: u.id == ug.user_id)
    |> where([a, g, ug, u], u.id == ^user_id)
    |> Repo.one()
  end

  @doc """
  Sets the `parent_id` of the Account with the specified `account_id`
  """
  @spec set_parent_account(account_id :: Account.id(), parent_id :: Account.id()) ::
          Account.t()
  def set_parent_account(account_id, parent_id) do
    account_id
    |> get_account()
    |> change(%{parent_id: parent_id})
    |> Repo.update!()
  end

  @doc """
  Returns `Account` associated with the `Project` specified by `project_id`,
  or `nil` if no `Account` is associated with it.
  """
  @spec get_project_account(Keila.Projects.Project.id()) :: Account.t() | nil
  def get_project_account(project_id) when is_id(project_id) do
    project = Keila.Projects.get_project(project_id)

    from(a in Account)
    |> join(:inner, [a], g in Auth.Group, on: g.id == a.group_id)
    |> join(:inner, [a, g], pg in Auth.Group, on: pg.parent_id == g.id)
    |> join(:inner, [a, g, pg], p in Keila.Projects.Project, on: p.group_id == pg.id)
    |> where([a, g, pg, p], p.id == ^project.id)
    |> Repo.one()
  end

  @doc """
  Changes the account a `User` is associated to.

  Returns `:ok` if successful, otherwise `:false`.

  ## Users with existing `Accounts`
  If `User` is already associated with another `Account` and that `Account` is
  not associated to any other `User`, their `Project`s are reassigned to the new
  `Account`. Otherwise, `:error` is returned.
  """
  @spec set_user_account(Auth.User.id(), Account.id()) :: :ok | :error
  def set_user_account(user_id, account_id) do
    previous_account = get_user_account(user_id)

    cond do
      is_nil(previous_account) ->
        do_set_user_account(user_id, account_id, previous_account)

      previous_account.id == account_id ->
        :ok

      Enum.count(list_account_users(previous_account.id)) == 1 ->
        do_set_user_account(user_id, account_id, previous_account)

      true ->
        :error
    end
  end

  defp do_set_user_account(user_id, account_id, previous_account) do
    account = get_account(account_id)

    Repo.transaction(fn ->
      Auth.add_user_to_group(user_id, account.group_id)

      if not is_nil(previous_account) do
        Auth.remove_user_from_group(user_id, previous_account.group_id)
      end

      project_group_ids = Keila.Projects.get_user_projects(user_id) |> Enum.map(& &1.group_id)

      from(g in Auth.Group, where: g.id in ^project_group_ids)
      |> Repo.update_all(set: [parent_id: account.group_id])
    end)
    |> case do
      {:ok, _} -> :ok
    end
  end

  @doc """
  Returns `true` if credits are enabled in the application configuration,
  otherwise `false`.
  """
  @spec credits_enabled?() :: boolean()
  def credits_enabled?() do
    Application.get_env(:keila, __MODULE__, []) |> Keyword.get(:credits_enabled) == true
  end

  @doc """
  Retrieves tuple with total of non-expired credits and available credits for
  Account with given `account_id`.

  If credits are disabled in the application configuration, always returns
  `{0, 0}`.

  For further information see `get_available_credits/1` and
  `get_total_credits/1`.
  """
  @spec get_credits(Account.id()) :: {integer(), integer()}
  def get_credits(account_id) do
    if credits_enabled?() do
      {get_total_credits(account_id), get_available_credits(account_id)}
    else
      {0, 0}
    end
  end

  @doc """
  Retrieves sum of available credits for Account with given `account_id`.
  This sum includes both positive and and negative credit transactions, i.e.
  it accounts for consumed credits.

  If credits are disabled in the application configuration, always returns `0`.

  ## Example
      add_credits(account_id, 10)
      consume_credits(account_id, 7)
      get_available_credits(account_id) # => 3
  """
  def get_available_credits(account_id) do
    if credits_enabled?() do
      credits_for_account(account_id)
      |> where([c], c.expires_at >= fragment("NOW()"))
      |> select([c], sum(c.amount))
      |> Repo.one()
      |> maybe_nil_to_zero()
    else
      0
    end
  end

  defp credits_for_account(account_id) do
    from(c in CreditTransaction,
      where:
        c.account_id == ^account_id or
          c.account_id in subquery(
            from a in Account, where: a.id == ^account_id, select: a.parent_id
          )
    )
  end

  @doc """
  Retrieves total of non-expired credits for Account with given `account_id`.
  This sum only includes positive credit transactions and does *not* account for
  consumed credits.

  If credits are disabled in the application configuration, always returns `0`.

  ## Example
      add_credits(account_id, 10)
      consume_credits(account_id, 7)
      get_total_credits(account_id) # => 10
  """
  def get_total_credits(account_id) do
    if credits_enabled?() do
      credits_for_account(account_id)
      |> where([c], c.expires_at >= fragment("NOW()"))
      |> where([c], c.amount > 0)
      |> select([c], sum(c.amount))
      |> Repo.one()
      |> maybe_nil_to_zero()
    else
      0
    end
  end

  @doc """
  Returns `true` if Account with given `account_id` has at least `amount`
  available credits, otherwise returns `false`.

  If credits are disabled in the application configuration, always returns `true`.
  """
  @spec has_credits?(Account.id(), integer()) :: true | false
  def has_credits?(account_id, amount) do
    if credits_enabled?() do
      get_credits(account_id) |> elem(1) >= amount
    else
      true
    end
  end

  @doc """
  Adds `amount` credits with expiry time `expires_at` to Account with given
  `account_id`.

  Returns `:ok` or `:error` if there was an error.

  If credits are disabled in the application configuration, always returns `:ok`.
  """
  @spec add_credits(Account.id(), integer(), DateTime.t()) :: :ok | :error
  def add_credits(account_id, amount, expires_at) do
    if credits_enabled?() do
      expires_at = DateTime.truncate(expires_at, :second)

      %CreditTransaction{account_id: account_id, amount: amount, expires_at: expires_at}
      |> Repo.insert()
      |> case do
        {:ok, _} -> :ok
        _ -> :error
      end
    else
      :ok
    end
  end

  @doc """
  Consumes `amount` credits for Account with given `account_id`.

  Credits with earlier expiry date are consumed first.

  Returns `:ok` if sufficient credits were available, otherwise `:error`.

  If credits are disabled in the application configuration, always returns `:ok`.
  """
  @spec consume_credits(Account.id(), integer()) :: :ok | :error
  def consume_credits(account_id, amount) do
    if credits_enabled?() do
      now = now()

      credits_for_account(account_id)
      |> where([c], c.expires_at >= ^now)
      |> order_by([c], c.expires_at)
      |> group_by([c], [c.account_id, c.expires_at])
      |> select([c], {c.account_id, sum(c.amount), c.expires_at})
      |> Repo.all()
      |> build_transactions(amount)
      |> maybe_insert_transactions()
    else
      :ok
    end
  end

  defp build_transactions(amount_tuples, amount) do
    Enum.reduce_while(amount_tuples, {amount, []}, fn amount_tuple, acc ->
      do_build_transactions(amount_tuple, acc)
    end)
  end

  defp do_build_transactions({_, available_amount, _}, acc) when available_amount == 0 do
    {:cont, acc}
  end

  defp do_build_transactions(
         {account_id, available_amount, expires_at},
         {remaining_amount, transactions}
       )
       when available_amount < remaining_amount do
    transaction = build_transaction(account_id, expires_at, -available_amount)
    {:cont, {remaining_amount - available_amount, [transaction | transactions]}}
  end

  defp do_build_transactions(
         {account_id, available_amount, expires_at},
         {remaining_amount, transactions}
       )
       when available_amount >= remaining_amount do
    transaction = build_transaction(account_id, expires_at, -remaining_amount)
    {:halt, {0, [transaction | transactions]}}
  end

  defp build_transaction(account_id, expires_at, amount) do
    %{
      account_id: account_id,
      expires_at: expires_at,
      amount: amount,
      inserted_at: now()
    }
  end

  defp now() do
    DateTime.utc_now() |> DateTime.truncate(:second)
  end

  defp maybe_insert_transactions({0, transactions}) do
    Repo.insert_all(CreditTransaction, transactions)
    :ok
  end

  defp maybe_insert_transactions(_), do: :error

  defp maybe_nil_to_zero(nil), do: 0
  defp maybe_nil_to_zero(int), do: int
end
