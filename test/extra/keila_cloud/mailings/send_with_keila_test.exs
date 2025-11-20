require Keila

Keila.if_cloud do
  defmodule KeilaCloud.Mailings.SendWithKeilaTest do
    use Keila.DataCase, async: true
    alias KeilaCloud.Mailings.SendWithKeila

    describe "use_fallback_domain/1" do
      @describetag :send_with_keila

      test "returns true for sender with shared/unverified domain" do
        sender = insert_sender!(known_shared_domain: true)
        assert SendWithKeila.use_fallback_domain(sender)
      end

      test "returns false for sender with verified custom domain" do
        sender = insert_sender!(verified: true, mx2_set_up: true)
        refute SendWithKeila.use_fallback_domain(sender)
      end

      test "returns true for sender with unverified custom domain" do
        sender = insert_sender!()
        assert SendWithKeila.use_fallback_domain(sender)
      end

      test "returns true for sender with domain verified but MX2 not set up" do
        sender = insert_sender!(verified: true)
        assert SendWithKeila.use_fallback_domain(sender)
      end
    end

    describe "rate_limit/1" do
      @describetag :send_with_keila

      test "returns lower rate limit for sender with shared/unverified domain" do
        sender = insert_sender!(known_shared_domain: true)
        assert [{:hour, 2500}, {:second, 5}] = SendWithKeila.rate_limit(sender)
      end

      test "returns higher rate limit for sender with verified custom domain" do
        sender = insert_sender!(verified: true, mx2_set_up: true)
        assert [{:hour, 15000}, {:second, 15}] = SendWithKeila.rate_limit(sender)
      end

      test "returns lower rate limit for sender with unverified custom domain" do
        sender = insert_sender!()
        assert [{:hour, 2500}, {:second, 5}] = SendWithKeila.rate_limit(sender)
      end

      test "returns lower rate limit for sender with domain verified but MX2 not set up" do
        sender = insert_sender!(verified: true)
        assert [{:hour, 2500}, {:second, 5}] = SendWithKeila.rate_limit(sender)
      end
    end

    describe "from/1 and reply_to/1" do
      @describetag :send_with_keila

      test "uses fallback domain when domain not verified" do
        sender = insert_sender!(known_shared_domain: true) |> Map.put(:from_name, "Test User")
        fallback_email = SendWithKeila.fallback_from_email(sender)

        assert {"Test User", ^fallback_email} = SendWithKeila.from(sender)
        assert {"Test User", "test@mailbox.org"} = SendWithKeila.reply_to(sender)
      end

      test "uses original domain when fully verified" do
        sender =
          insert_sender!(verified: true, mx2_set_up: true) |> Map.put(:from_name, "Test User")

        assert {"Test User", "test@example.com"} = SendWithKeila.from(sender)
        assert nil == SendWithKeila.reply_to(sender)
      end

      test "handles reply_to when set" do
        sender =
          insert_sender!(verified: true, mx2_set_up: true)
          |> Map.put(:reply_to_email, "reply@example.com")
          |> Map.put(:reply_to_name, "Reply User")

        assert {"Reply User", "reply@example.com"} = SendWithKeila.reply_to(sender)
      end
    end

    describe "to_swoosh_config/1" do
      @describetag :send_with_keila

      test "returns config for verified sender" do
        sender = insert_sender!(verified: true, mx2_set_up: true)

        config = SendWithKeila.to_swoosh_config(sender)
        assert config[:adapter] == Swoosh.Adapters.AmazonSES
      end

      test "raises error for unverified from_email" do
        sender = insert_sender!() |> Map.put(:verified_from_email, nil)

        assert_raise FunctionClauseError, fn ->
          SendWithKeila.to_swoosh_config(sender)
        end
      end

      test "raises error when from_email doesn't match verified_from_email" do
        sender =
          insert_sender!()
          |> Map.put(:verified_from_email, "other@example.com")

        assert_raise FunctionClauseError, fn ->
          SendWithKeila.to_swoosh_config(sender)
        end
      end
    end

    defp insert_sender!(opts \\ []) do
      verified = Keyword.get(opts, :verified, false)
      mx2_set_up = Keyword.get(opts, :mx2_set_up, false)
      known_shared_domain = Keyword.get(opts, :known_shared_domain, false)
      now = DateTime.utc_now(:second)

      group = insert!(:group)
      project = insert!(:project, group: group)
      email = if known_shared_domain, do: "test@mailbox.org", else: "test@example.com"

      insert!(:mailings_sender,
        project: project,
        from_email: email,
        verified_from_email: email,
        config: %{
          type: "send_with_keila",
          swk_domain: if(known_shared_domain, do: "mailbox.org", else: "example.com"),
          swk_domain_is_known_shared_domain: known_shared_domain,
          swk_domain_verified_at: if(verified, do: now, else: nil),
          swk_domain_checked_at: now,
          swk_mx2_set_up_at: if(mx2_set_up, do: now, else: nil)
        }
      )
    end
  end
end
