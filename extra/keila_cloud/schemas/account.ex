require Keila

Keila.if_cloud do
  defmodule KeilaCloud.Accounts.Account do
    defmacro __using__(_opts) do
      quote do
        embeds_one(:contact_data, KeilaCloud.Accounts.Account.ContactData)

        embeds_one(
          :onboarding_review_data,
          KeilaCloud.Accounts.Account.OnboardingReviewData
        )

        field :status, Ecto.Enum,
          values: [
            default: 0,
            active: 1,
            suspended: -1,
            onboarding_required: 10,
            under_review: 11
          ]
      end
    end
  end
end
