require Keila

Keila.if_cloud do
  defmodule KeilaCloud.Accounts do
    use Keila.Repo
    alias Keila.Accounts.Account
    alias KeilaCloud.Accounts.Account.CloudData
    alias KeilaCloud.Accounts.Account.ContactData
    alias KeilaCloud.Accounts.Account.OnboardingReviewData

    def update_account_contact_data(account_id, params, required_fields \\ []) do
      account = Keila.Accounts.get_account(account_id)
      contact_data = account.contact_data || %ContactData{}
      changeset = ContactData.changeset(contact_data, params, required_fields)

      account
      |> change(%{contact_data: changeset})
      |> Repo.update()
    end

    def update_onboarding_review_data(account_id, params) do
      account = Keila.Accounts.get_account(account_id)

      onboarding_review_data = account.onboarding_review_data || %OnboardingReviewData{}
      changeset = OnboardingReviewData.changeset(onboarding_review_data, params)

      account
      |> change(%{onboarding_review_data: changeset})
      |> Repo.update()
    end

    def update_account_cloud_data(account_id, params) do
      account = Keila.Accounts.get_account(account_id)
      cloud_data = account.cloud_data || %CloudData{}
      changeset = CloudData.changeset(cloud_data, params)

      account
      |> change(%{cloud_data: changeset})
      |> Repo.update()
    end

    def update_account_status(account_id, status) do
      Keila.Accounts.get_account(account_id)
      |> cast(%{status: status}, [:status])
      |> Repo.update()
    end

    @doc """
    Narrows a `Keila.Auth.User` query to Users belonging to an Account with the
    given `status`. Unknown statuses match no Users.
    """
    def filter_users_by_account_status(query, status) do
      case cast_account_status(status) do
        {:ok, status} ->
          user_ids =
            from ug in Keila.Auth.UserGroup,
              join: a in Account,
              on: a.group_id == ug.group_id,
              where: a.status == ^status,
              select: ug.user_id

          where(query, [u], u.id in subquery(user_ids))

        :error ->
          where(query, false)
      end
    end

    defp cast_account_status(status) do
      Ecto.Enum.values(Account, :status)
      |> Enum.find(&(to_string(&1) == to_string(status)))
      |> case do
        nil -> :error
        status -> {:ok, status}
      end
    end

    def handle_subscription_created(account_id) do
      account = Keila.Accounts.get_account(account_id)

      if account && account.status == :default do
        update_account_status(account.id, :onboarding_required)
      end
    end
  end
end
