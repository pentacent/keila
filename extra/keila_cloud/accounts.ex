require Keila

Keila.if_cloud do
  defmodule KeilaCloud.Accounts do
    use Keila.Repo
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

    def update_account_status(account_id, status) do
      Keila.Accounts.get_account(account_id)
      |> cast(%{status: status}, [:status])
      |> Repo.update()
    end

    def handle_subscription_created(account_id) do
      account = Keila.Accounts.get_account(account_id)

      if account && account.status == :default do
        update_account_status(account.id, :onboarding_required)
      end
    end
  end
end
