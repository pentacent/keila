defmodule Keila.Auth.TwoFactorTest do
  use Keila.DataCase, async: true
  alias Keila.Auth

  setup do
    insert!(:group, name: "root", parent_id: nil)
    user = insert!(:user, email: "test@example.com")
    %{user: user}
  end

  describe "two_factor_auth" do
    test "enable_two_factor_auth/1 enables 2FA and generates backup codes", %{user: user} do
      refute user.two_factor_enabled
      
      assert {:ok, updated_user} = Auth.enable_two_factor_auth(user.id)
      assert updated_user.two_factor_enabled
      assert length(updated_user.two_factor_backup_codes) == 10
    end

    test "disable_two_factor_auth/1 disables 2FA and clears backup codes", %{user: user} do
      # First enable 2FA
      {:ok, user_with_2fa} = Auth.enable_two_factor_auth(user.id)
      assert user_with_2fa.two_factor_enabled
      
      # Then disable it
      assert {:ok, updated_user} = Auth.disable_two_factor_auth(user.id)
      refute updated_user.two_factor_enabled
      assert updated_user.two_factor_backup_codes == []
    end

    test "send_two_factor_code/1 sends code for 2FA enabled user", %{user: user} do
      # Enable 2FA first
      {:ok, _user_with_2fa} = Auth.enable_two_factor_auth(user.id)
      
      assert {:ok, code} = Auth.send_two_factor_code(user.id)
      assert is_binary(code)
      assert String.length(code) == 6
      assert code =~ ~r/^\d{6}$/
      
      # Check that email was sent
      assert_email_sent()
    end

    test "send_two_factor_code/1 returns error for user without 2FA", %{user: user} do
      assert :error = Auth.send_two_factor_code(user.id)
      assert_no_email_sent()
    end

    test "verify_two_factor_code/2 verifies valid code", %{user: user} do
      # Enable 2FA first
      {:ok, _user_with_2fa} = Auth.enable_two_factor_auth(user.id)
      
      # Send code
      {:ok, code} = Auth.send_two_factor_code(user.id)
      
      # Verify code
      assert {:ok, verified_user} = Auth.verify_two_factor_code(user.id, code)
      assert verified_user.id == user.id
    end

    test "verify_two_factor_code/2 rejects invalid code", %{user: user} do
      # Enable 2FA first
      {:ok, _user_with_2fa} = Auth.enable_two_factor_auth(user.id)
      
      # Try to verify invalid code
      assert :error = Auth.verify_two_factor_code(user.id, "123456")
    end

    test "verify_two_factor_code/2 works with backup codes", %{user: user} do
      # Enable 2FA first
      {:ok, user_with_2fa} = Auth.enable_two_factor_auth(user.id)
      backup_code = List.first(user_with_2fa.two_factor_backup_codes)
      
      # Verify with backup code
      assert {:ok, verified_user} = Auth.verify_two_factor_code(user.id, backup_code)
      assert verified_user.id == user.id
      
      # Check that backup code was removed
      refute backup_code in verified_user.two_factor_backup_codes
      assert length(verified_user.two_factor_backup_codes) == 9
    end
  end
end
