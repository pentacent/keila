require Keila

Keila.if_cloud do
  defmodule KeilaWeb.CloudPartnerController do
    use KeilaWeb, :controller

    alias Keila.Accounts
    alias KeilaCloud.Partners

    plug :authorize_partner

    @page_size 20

    def index(conn, params) do
      partner_account = conn.assigns.current_account
      page = String.to_integer(Map.get(params, "page", "1")) - 1

      child_accounts =
        Partners.list_partner_child_accounts(partner_account.id,
          paginate: [page: page, page_size: @page_size]
        )

      conn
      |> put_meta(:title, dgettext("cloud", "Partner Area"))
      |> assign(:partner_account, partner_account)
      |> assign(:partner_credits, get_partner_credits(partner_account.id))
      |> assign(:child_accounts, child_accounts)
      |> assign(:child_credits, get_child_credits(child_accounts.data))
      |> assign(:child_users, get_child_users(child_accounts.data))
      |> assign(:allocations, allocations_by_account(partner_account))
      |> assign(:projection, Partners.project_partner_next_cycle(partner_account.id))
      |> render("index.html")
    end

    def show_credits(conn, %{"id" => child_account_id}) do
      with {:ok, child_account} <- fetch_child(conn, child_account_id) do
        partner_account = conn.assigns.current_account

        conn
        |> put_meta(:title, dgettext("cloud", "Manage child account credits"))
        |> assign(:partner_account, partner_account)
        |> assign(:partner_credits, get_partner_credits(partner_account.id))
        |> assign(:child_account, child_account)
        |> assign(:child_user, child_account.id |> Accounts.list_account_users() |> List.first())
        |> assign(:child_credits, Accounts.get_credits(child_account.id))
        |> assign(:allocation, allocation_for(partner_account, child_account.id))
        |> render("show_credits.html")
      end
    end

    def create_credits(conn, %{"id" => child_account_id, "credits" => params}) do
      with {:ok, child_account} <- fetch_child(conn, child_account_id),
           {amount, ""} when amount > 0 <- Integer.parse(params["amount"] || "") do
        do_transfer_credits(conn, child_account, amount)
      else
        _ ->
          conn
          |> put_flash(:error, dgettext("cloud", "Please enter a valid amount."))
          |> redirect(to: ~p"/partner/accounts/#{child_account_id}/credits")
      end
    end

    def update_credit_allocation(conn, %{
          "id" => child_account_id,
          "allocation" => %{"credits" => credits_param}
        }) do
      with {:ok, child_account} <- fetch_child(conn, child_account_id),
           {credits, ""} when credits >= 0 <- Integer.parse(credits_param || "") do
        case Partners.update_credit_allocation(
               conn.assigns.current_account.id,
               child_account.id,
               credits
             ) do
          {:ok, _} ->
            conn
            |> put_flash(:info, dgettext("cloud", "Monthly credit allocation updated."))
            |> redirect(to: ~p"/partner/accounts/#{child_account.id}/credits")

          {:error, _} ->
            conn
            |> put_flash(:error, dgettext("cloud", "Could not update credit allocation."))
            |> redirect(to: ~p"/partner/accounts/#{child_account.id}/credits")
        end
      else
        _ ->
          conn
          |> put_flash(:error, dgettext("cloud", "Please enter a non-negative number."))
          |> redirect(to: ~p"/partner/accounts/#{child_account_id}/credits")
      end
    end

    def new(conn, _params) do
      conn
      |> put_meta(:title, dgettext("cloud", "Add child account"))
      |> assign(:changeset, Ecto.Changeset.change(%Keila.Auth.User{}))
      |> render("new.html")
    end

    def create(conn, %{"user" => params}) do
      partner_account = conn.assigns.current_account

      case Partners.create_child_account_user(partner_account.id, params) do
        {:ok, %{account: account}} ->
          conn
          |> put_flash(:info, dgettext("cloud", "Child account created."))
          |> redirect(to: ~p"/partner/accounts/#{account.id}/credits")

        {:error, %Ecto.Changeset{} = changeset} ->
          conn
          |> put_flash(:error, dgettext("cloud", "Could not create child account."))
          |> assign(:changeset, %{changeset | action: :insert})
          |> render("new.html")
      end
    end

    def update_password(conn, %{
          "id" => child_user_id,
          "user" => %{"password" => password} = params
        }) do
      partner_account = conn.assigns.current_account
      child_account = Accounts.get_user_account(child_user_id)

      case Partners.update_child_account_user_password(partner_account.id, child_user_id, params) do
        {:ok, _user} ->
          conn
          |> put_flash(:info, dgettext("cloud", "Password updated."))
          |> redirect(to: ~p"/partner/accounts/#{child_account.id}/credits")

        {:error, :not_a_child} ->
          conn
          |> put_flash(:error, dgettext("cloud", "Not found."))
          |> redirect(to: ~p"/partner")

        {:error, %Ecto.Changeset{}} ->
          conn
          |> put_flash(:error, dgettext("cloud", "Password change not accepted."))
          |> redirect(to: ~p"/partner/accounts/#{child_account.id}/credits")
      end
    end

    def login_as(conn, %{"id" => user_id}) do
      partner_account = conn.assigns.current_account

      if Partners.partner_of?(partner_account.id, user_id) do
        conn
        |> KeilaWeb.AuthSession.end_auth_session()
        |> KeilaWeb.AuthSession.start_auth_session(user_id)
        |> redirect(to: ~p"/")
      else
        conn |> put_status(404) |> halt()
      end
    end

    defp do_transfer_credits(conn, child_account, amount) do
      partner_account = conn.assigns.current_account

      flash =
        case Partners.transfer_credits(partner_account.id, child_account.id, amount) do
          :ok -> {:info, dgettext("cloud", "Credits transferred.")}
          {:error, :insufficient_credits} -> {:error, dgettext("cloud", "Not enough credits.")}
          {:error, _} -> {:error, dgettext("cloud", "Could not transfer credits.")}
        end

      conn
      |> put_flash(elem(flash, 0), elem(flash, 1))
      |> redirect(to: ~p"/partner/accounts/#{child_account.id}/credits")
    end

    defp fetch_child(conn, child_account_id) do
      partner_id = conn.assigns.current_account.id
      account = Accounts.get_account(child_account_id)

      if account && account.parent_id == partner_id do
        {:ok, account}
      else
        {:error,
         conn
         |> put_status(404)
         |> halt()}
      end
    end

    defp authorize_partner(conn, _) do
      account = conn.assigns[:current_account]

      if account && account.is_partner do
        conn
      else
        conn |> put_status(404) |> halt()
      end
    end

    defp allocations_by_account(partner_account) do
      Partners.partner_credit_allocations(partner_account.id)
    end

    defp allocation_for(partner_account, child_account_id) do
      partner_account.id
      |> Partners.partner_credit_allocations()
      |> Map.get(child_account_id)
    end

    defp get_partner_credits(account_id) do
      if Accounts.credits_enabled?(), do: Accounts.get_credits(account_id)
    end

    defp get_child_credits(accounts) do
      if Accounts.credits_enabled?() do
        Enum.into(accounts, %{}, &{&1.id, Accounts.get_credits(&1.id)})
      end
    end

    defp get_child_users(accounts) do
      Enum.into(accounts, %{}, fn account ->
        {account.id, account.id |> Accounts.list_account_users() |> List.first()}
      end)
    end
  end
end
