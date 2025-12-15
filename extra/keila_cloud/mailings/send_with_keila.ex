require Keila

Keila.if_cloud do
  defmodule KeilaCloud.Mailings.SendWithKeila do
    use Keila.Mailings.SenderAdapters.Adapter
    alias KeilaCloud.DNS
    alias __MODULE__.Mx2
    import Ecto.Changeset

    @type entry :: :mx1 | :mx2 | :dkim1 | :dkim2 | :dmarc
    @entries [:mx1, :mx2, :dkim1, :dkim2, :dmarc]
    @entry_types [mx1: :cname, mx2: :cname, dkim1: :cname, dkim2: :cname, dmarc: :txt]

    @defaults [
      mx1: "keila-mx1",
      mx2: "keila-mx2",
      dkim1: "keila1",
      dkim2: "keila2"
    ]
    @expected_values [
      mx1: "mx1.public.keila.io",
      mx2: "mx2.public.keila.io",
      dkim1: "dkim1.public.keila.io",
      dkim2: "dkim2.public.keila.io",
      dmarc: "v=DMARC1; p=none"
    ]
    @expected_legacy_values [
      mx2: "public.keila.io",
      dkim2: "dkim.public.keila.io"
    ]

    @fallback_domain "keilamails.com"

    @external_resource "priv/extra/known-shared-domains.txt"
    @known_shared_domains File.read!("priv/extra/known-shared-domains.txt") |> String.split("\n")

    @impl true
    def name, do: "send_with_keila"

    @impl true
    def schema_fields do
      [
        swk_custom_mx1: :string,
        swk_custom_mx2: :string,
        swk_custom_dkim1: :string,
        swk_custom_dkim2: :string,
        swk_preferred_server: :integer,
        swk_domain: :string,
        swk_domain_verified_at: :utc_datetime,
        swk_domain_checked_at: :utc_datetime,
        swk_domain_is_known_shared_domain: :boolean,
        swk_mx1_value: :string,
        swk_mx2_value: :string,
        swk_dkim1_value: :string,
        swk_dkim2_value: :string,
        swk_dmarc_value: :string,
        swk_mx1_set_up_at: :utc_datetime,
        swk_mx2_set_up_at: :utc_datetime,
        swk_is_legacy: :boolean
      ]
    end

    @impl true
    def changeset(changeset, params) do
      changeset
      |> cast(params, [
        :swk_custom_mx1,
        :swk_custom_mx2,
        :swk_custom_dkim1,
        :swk_custom_dkim2,
        :swk_preferred_server
      ])
    end

    @impl true
    def update_changeset(changeset) do
      if changed?(changeset, :from_email) do
        config_changeset =
          get_field(changeset, :config)
          |> Ecto.Changeset.change(%{
            swk_is_legacy: false,
            swk_custom_mx1: nil,
            swk_custom_mx2: nil,
            swk_custom_dkim1: nil,
            swk_custom_dkim2: nil,
            swk_domain: nil,
            swk_domain_verified_at: nil,
            swk_domain_checked_at: nil,
            swk_domain_is_known_shared_domain: nil,
            swk_mx1_set_up_at: nil,
            swk_mx2_set_up_at: nil
          })

        change(changeset, %{config: config_changeset})
      else
        changeset
      end
    end

    @impl true
    def configurable?(), do: false

    @impl true
    def requires_verification?(), do: true

    @impl true
    def after_create(sender) do
      verify_domain_async(sender.id)
    end

    @impl true
    def after_update(sender) do
      if sender.verified_from_email do
        verify_domain_async(sender.id)
      end

      :ok
    end

    @impl true
    def to_swoosh_config(
          %{verified_from_email: verified_from_email, from_email: from_email, config: config} =
            sender
        )
        when verified_from_email == from_email and not is_nil(from_email) do
      # TODO: This is where MX1 can be used in the future
      case config.swk_preferred_server do
        _default -> Mx2.to_swoosh_config(sender)
      end
    end

    @impl true
    def put_provider_options(email, sender) do
      case sender.config.swk_preferred_server do
        _default -> Mx2.put_provider_options(email, sender)
      end
    end

    @impl true
    def from(sender) do
      Mx2.from(sender)
    end

    @impl true
    def reply_to(sender) do
      Mx2.reply_to(sender)
    end

    @impl true
    def rate_limit(sender) do
      Mx2.rate_limit(sender)
    end

    @impl true
    def adapter_rate_limit() do
      Application.get_env(:keila, __MODULE__, [])
      |> Keyword.get(:adapter_rate_limits, nil)
    end

    @impl true
    def deliver_verification_email(sender, token, url_fn) do
      :ok = Mx2.maybe_remove_email_from_suppression_list(sender.from_email)

      Keila.Auth.Emails.send!(:verify_sender_from_email, %{
        sender: sender,
        url: url_fn.(token)
      })
    end

    @doc """
    Verifies the domain of the sender's email address.
    Returns the updated sender in an `:ok` tuple.
    """
    @spec verify_domain(Sender.t()) :: {:ok, Sender.t()} | {:error, term()}
    def verify_domain(sender) do
      with {:ok, domain} <- email_domain(sender.from_email),
           {:ok, sender} <- verify_domain_is_not_shared(sender, domain),
           {:ok, sender} <- verify_dns_entries(sender, domain),
           {:ok, sender} <- __MODULE__.Mx2.maybe_set_up_domain(sender) do
        {:ok, sender}
      else
        {:shared_domain, sender} -> {:ok, sender}
        other -> other
      end
    end

    @doc """
    Enqueues the Sender for async domain verification.
    """
    @spec verify_domain_async(Sender.id()) :: :ok
    def verify_domain_async(sender_id) do
      KeilaCloud.Workers.SenderDomainVerificationWorker.new(%{"sender_id" => sender_id})
      |> Oban.insert!()

      :ok
    end

    @doc """
    Returns the expected subdomain for the given `entry`.
    """
    @spec subdomain(Sender.t(), entry()) :: String.t()
    def subdomain(%Sender{config: config}, entry) when entry in @entries do
      case entry do
        :mx1 -> config.swk_custom_mx1 || @defaults[entry]
        :mx2 -> config.swk_custom_mx2 || @defaults[entry]
        :dkim1 -> (config.swk_custom_dkim1 || @defaults[entry]) <> "._domainkey"
        :dkim2 -> (config.swk_custom_dkim2 || @defaults[entry]) <> "._domainkey"
        :dmarc -> "_dmarc"
      end
    end

    @doc """
    Returns the expected value for the given `entry`.
    """
    @spec expected_value(Sender.t(), entry()) :: String.t()
    def expected_value(sender, entry) when entry in @entries do
      if sender.config.swk_is_legacy do
        @expected_legacy_values[entry]
      else
        @expected_values[entry]
      end
    end

    @doc """
    Returns `true` if the entry value is valid for the given Sender.
    """
    @spec entry_valid?(Sender.t(), entry(), String.t() | nil) :: boolean()
    def entry_valid?(sender, entry, value)
    def entry_valid?(_sender, :dmarc, value), do: DNS.valid_dmarc?(value)
    def entry_valid?(sender, entry, value), do: value == expected_value(sender, entry)

    @spec entry_type(entry()) :: :txt | :cname
    def entry_type(entry) when entry in @entries, do: @entry_types[entry]

    @doc """
    Returns the domain part from an email address.
    """
    @spec email_domain(String.t()) :: {:ok, String.t()} | {:error, String.t()}
    def email_domain(email) when is_binary(email) do
      case Regex.run(~r/@([^@]+)$/, email) do
        [_, domain] -> {:ok, domain}
        _ -> {:error, "invalid email"}
      end
    end

    @doc false
    def private_changeset(changeset, params) do
      changeset
      |> cast(params, [
        :swk_domain,
        :swk_domain_verified_at,
        :swk_domain_checked_at,
        :swk_domain_is_known_shared_domain,
        :swk_mx1_value,
        :swk_mx2_value,
        :swk_dkim1_value,
        :swk_dkim2_value,
        :swk_dmarc_value,
        :swk_is_legacy,
        :swk_custom_mx2,
        :swk_custom_dkim2,
        :swk_mx1_set_up_at,
        :swk_mx2_set_up_at
      ])
    end

    defp verify_domain_is_not_shared(sender, domain) do
      if domain in @known_shared_domains do
        {:ok, sender} =
          update_sender_config(
            sender,
            %{
              swk_domain_is_known_shared_domain: true
            },
            skip_callback: true
          )

        {:shared_domain, sender}
      else
        {:ok, sender}
      end
    end

    defp verify_dns_entries(sender, domain) do
      entry_values = fetch_dns_entry_values(sender, domain)
      valid? = entries_valid?(sender, entry_values)
      now = DateTime.utc_now(:second)

      update_sender_config(
        sender,
        %{
          swk_domain: domain,
          swk_domain_verified_at: if(valid?, do: now, else: nil),
          swk_domain_checked_at: now,
          swk_mx1_value: entry_values[:mx1],
          swk_mx2_value: entry_values[:mx2],
          swk_dkim1_value: entry_values[:dkim1],
          swk_dkim2_value: entry_values[:dkim2],
          swk_dmarc_value: entry_values[:dmarc]
        },
        skip_callback: true
      )
    end

    defp entries_valid?(sender = %{config: %{swk_is_legacy: true}}, entry_values) do
      entry_values[:mx2] == expected_value(sender, :mx2) and
        entry_values[:dkim2] == expected_value(sender, :dkim2) and
        DNS.valid_dmarc?(entry_values[:dmarc])
    end

    defp entries_valid?(sender, entry_values) do
      Enum.all?(entry_values, fn {entry, value} ->
        entry_valid?(sender, entry, value)
      end)
    end

    defp fetch_dns_entry_values(sender, domain) do
      for entry <- @entries do
        subdomain = subdomain(sender, entry)

        value =
          case DNS.lookup(domain, subdomain, @entry_types[entry]) do
            {:ok, value} -> value
            _ -> nil
          end

        {entry, value}
      end
    end

    def reset_legacy_settings(sender) do
      update_sender_config(sender, %{swk_is_legacy: false, swk_custom_mx2: nil})
    end

    defp update_sender_config(sender, config_attrs, opts \\ []) do
      Keila.Mailings.update_sender(
        sender.id,
        %{
          config: config_attrs |> Map.put(:id, sender.config.id)
        },
        [config_cast_opts: [with: &private_changeset(&1, &2)]] ++ opts
      )
      |> case do
        {:ok, sender} -> {:ok, sender}
        {:action_required, sender} -> {:ok, sender}
        {:error, reason} -> {:error, reason}
      end
    end

    def use_fallback_domain(sender) do
      Mx2.use_fallback_domain?(sender)
    end

    def fallback_from_email(sender) do
      String.replace(sender.from_email, "@", ".") <> "@" <> @fallback_domain
    end
  end
end
