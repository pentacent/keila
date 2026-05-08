require Keila

Keila.if_cloud do
  defmodule KeilaCloud.PartnersTest.PartnerAccounts do
    use Keila.DataCase, async: false

    alias Keila.Accounts
    alias Keila.Auth
    alias KeilaCloud.Partners

    setup do
      partner_account = insert!(:account)
      {:ok, partner_account} = Partners.set_is_partner(partner_account.id, true)
      %{partner: partner_account}
    end

    describe "create_child_account_user/3" do
      test "creates an active, activated user as a child of the partner",
           %{partner: partner} do
        params = %{
          "email" => "child-#{System.unique_integer([:positive])}@example.com",
          "password" => "BatteryHorseStaple"
        }

        assert {:ok, %{user: user, account: account}} =
                 Partners.create_child_account_user(partner.id, params)

        assert account.parent_id == partner.id
        assert account.status == :active
        assert user.activated_at
        assert Accounts.get_user_account(user.id).id == account.id
      end

      test "fails when a user with the same email already exists",
           %{partner: partner} do
        email = "dupe-#{System.unique_integer([:positive])}@example.com"

        {:ok, _} =
          Auth.create_user(%{"email" => email, "password" => "BatteryHorseStaple"},
            skip_activation_email: true
          )

        assert {:error, %Ecto.Changeset{}} =
                 Partners.create_child_account_user(partner.id, %{
                   "email" => email,
                   "password" => "BatteryHorseStaple"
                 })
      end
    end
  end
end
