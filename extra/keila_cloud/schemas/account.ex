require Keila

Keila.if_cloud do
  defmodule KeilaCloud.Accounts.Account do
    import Ecto.Changeset

    alias KeilaCloud.Partners.PartnerSettings

    defmacro __using__(_opts) do
      quote do
        embeds_one(:contact_data, KeilaCloud.Accounts.Account.ContactData)

        embeds_one(
          :onboarding_review_data,
          KeilaCloud.Accounts.Account.OnboardingReviewData
        )

        embeds_one(:cloud_data, KeilaCloud.Accounts.Account.CloudData)

        embeds_one(:partner_settings, KeilaCloud.Partners.PartnerSettings, on_replace: :update)

        field :is_partner, :boolean, default: false

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

    def is_partner_changeset(account, is_partner?) do
      cast(account, %{is_partner: is_partner?}, [:is_partner])
    end

    def partner_settings_changeset(account, params) do
      settings = account.partner_settings || %PartnerSettings{}
      change(account, %{partner_settings: PartnerSettings.changeset(settings, params)})
    end
  end
end
