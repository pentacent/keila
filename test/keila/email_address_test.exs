defmodule Keila.EmailAddressTest do
  use ExUnit.Case, async: true
  import Ecto.Changeset
  alias Keila.EmailAddress

  doctest Keila.EmailAddress

  describe "to_mailbox_strings/1" do
    test "normalizes an RFC 5322 address-list string into a list with single RFC 5322 mailboxes" do
      assert {:ok, ["Lois <lois@example.com>", "peter@example.com"]} =
               EmailAddress.to_mailbox_strings("Lois <lois@example.com>, peter@example.com")
    end

    test "normalizes a list of mixed single mailboxes and address-list strings" do
      assert {:ok, ["Stewie <stewie@example.com>", "brian@example.com", "lois@example.com"]} =
               EmailAddress.to_mailbox_strings([
                 "Stewie <stewie@example.com>, brian@example.com",
                 "lois@example.com"
               ])
    end

    test "keeps a quoted comma inside a display name as one mailbox" do
      assert {:ok, [~s("Griffin, Peter" <peter@example.com>)]} =
               EmailAddress.to_mailbox_strings(~s("Griffin, Peter" <peter@example.com>))
    end

    test "returns :error when any address is invalid" do
      assert :error = EmailAddress.to_mailbox_strings(["stewie@example.com", "@@ not valid @@"])
    end

    test "nil results in an empty list" do
      assert {:ok, []} = EmailAddress.to_mailbox_strings(nil)
    end
  end

  describe "valid?/1" do
    test "accepts a single email address" do
      assert EmailAddress.valid?("brian@example.com")
      assert EmailAddress.valid?("lois+tag@example.com")
    end

    test "rejects an address with a display name" do
      refute EmailAddress.valid?("Peter <peter@example.com>")
    end

    test "rejects multiple addresses" do
      refute EmailAddress.valid?("stewie@example.com, brian@example.com")
    end

    test "rejects invalid strings and non-strings" do
      refute EmailAddress.valid?("not an email")
      refute EmailAddress.valid?(nil)
      refute EmailAddress.valid?(123)
    end
  end

  describe "valid_mailbox?/1" do
    test "accepts an email address and an address with a display name" do
      assert EmailAddress.valid_mailbox?("peter@example.com")
      assert EmailAddress.valid_mailbox?("Peter <peter@example.com>")
    end

    test "rejects multiple addresses, invalid strings, and non-strings" do
      refute EmailAddress.valid_mailbox?("stewie@example.com, brian@example.com")
      refute EmailAddress.valid_mailbox?("not an email")
      refute EmailAddress.valid_mailbox?(nil)
    end
  end

  describe "validate_email/3" do
    defp changeset(value) do
      {%{}, %{email: :string}}
      |> cast(%{"email" => value}, [:email])
      |> EmailAddress.validate_email(:email)
    end

    test "passes a single bare email address" do
      assert changeset("lois@example.com").valid?
    end

    test "rejects a display name, a list, and invalid strings" do
      refute changeset("Peter <peter@example.com>").valid?
      refute changeset("stewie@example.com, brian@example.com").valid?
      refute changeset("nope").valid?
    end

    test "does not run when the field is absent" do
      cs =
        {%{}, %{email: :string}}
        |> cast(%{}, [:email])
        |> EmailAddress.validate_email(:email)

      assert cs.valid?
    end

    test "uses a custom :message option" do
      cs = EmailAddress.validate_email(changeset_with_change("nope"), :email, message: "bad")
      assert "bad" in errors_on(cs).email
    end

    defp changeset_with_change(value) do
      {%{}, %{email: :string}}
      |> cast(%{"email" => value}, [:email])
    end

    defp errors_on(changeset) do
      Ecto.Changeset.traverse_errors(changeset, fn {message, _opts} -> message end)
    end
  end

  describe "validate_mailbox_list/3" do
    defp mailbox_list_changeset(value) do
      {%{}, %{cc: {:array, :string}}}
      |> cast(%{"cc" => value}, [:cc])
      |> EmailAddress.validate_mailbox_list(:cc)
    end

    test "passes a list of bare addresses and mailboxes with display names" do
      assert mailbox_list_changeset(["peter@example.com", "Lois <lois@example.com>"]).valid?
    end

    test "passes an empty list" do
      assert mailbox_list_changeset([]).valid?
    end

    test "rejects a list containing an invalid mailbox" do
      refute mailbox_list_changeset(["peter@example.com", "@@ nope @@"]).valid?
    end

    test "rejects a list whose entry holds more than one address" do
      refute mailbox_list_changeset(["stewie@example.com, brian@example.com"]).valid?
    end

    test "uses a custom :message option" do
      cs =
        {%{}, %{cc: {:array, :string}}}
        |> cast(%{"cc" => ["nope"]}, [:cc])
        |> EmailAddress.validate_mailbox_list(:cc, message: "bad")

      assert "bad" in Ecto.Changeset.traverse_errors(cs, fn {message, _opts} -> message end).cc
    end
  end
end
