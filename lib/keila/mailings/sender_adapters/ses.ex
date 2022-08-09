defmodule Keila.Mailings.SenderAdapters.SES do
  use Keila.Mailings.SenderAdapters.Adapter

  @impl true
  def name, do: "ses"

  @impl true
  def schema_fields do
    [
      ses_region: :string,
      ses_access_key: :string,
      ses_secret: :string,
      ses_configuration_set: :string
    ]
  end

  @impl true
  def changeset(changeset, params) do
    changeset
    |> cast(params, [:ses_region, :ses_access_key, :ses_secret, :ses_configuration_set])
    |> validate_required([:ses_region, :ses_access_key, :ses_secret])
  end

  @impl true
  def to_swoosh_config(%{config: config}) do
    [
      adapter: Swoosh.Adapters.AmazonSES,
      region: config.ses_region,
      access_key: config.ses_access_key,
      secret: config.ses_secret
    ]
  end

  @impl true
  def put_provider_options(email, %{config: config}) do
    case config.ses_configuration_set do
      nil ->
        email

      configuration_set ->
        Swoosh.Email.put_provider_option(email, :configuration_set_name, configuration_set)
    end
  end

  @doc """
  Validates the signature of a SNS message
  """
  @spec valid_signature?(map()) :: boolean()
  def valid_signature?(notification) do
    key = fetch_key(notification["SigningCertURL"])

    if key do
      serialized_notification =
        notification
        |> Map.take(~w[Message MessageId SubscribeURL Subject Timestamp Token TopicArn Type])
        |> Enum.sort_by(fn {key, _value} -> key end)
        |> Enum.flat_map(fn {key, value} -> [key, value] end)
        |> Enum.join("\n")
        |> String.replace_suffix("", "\n")

      signature = notification["Signature"] |> Base.decode64!()

      :public_key.verify(serialized_notification, :sha, signature, key)
    else
      false
    end
  end

  defp fetch_key(url) do
    cached_key = fetch_cached_key(url)

    if cached_key do
      cached_key
    else
      uri = URI.parse(url)

      if uri.host =~ ~r{^sns\.[a-z1-9-]+\.amazonaws\.com$} do
        key =
          HTTPoison.get!(url)
          |> then(fn %{body: pem_file} -> extract_key(pem_file) end)

        put_cached_key(url, key)

        key
      end
    end
  end

  defp fetch_cached_key(url) do
    if not is_nil(Process.whereis(__MODULE__.Cache)) do
      Agent.get(__MODULE__.Cache, &Map.get(&1, url))
    end
  end

  defp put_cached_key(url, key) do
    if is_nil(Process.whereis(__MODULE__.Cache)) do
      Agent.start_link(fn -> %{} end, name: __MODULE__.Cache)
    end

    Agent.update(__MODULE__.Cache, &Map.put(&1, url, key))
  end

  defp extract_key(pem_file) do
    pem_file
    |> :public_key.pem_decode()
    |> then(fn [{_, cert, _}] -> :public_key.pkix_decode_cert(cert, :otp) end)
    |> fetch_record_field(:OTPTBSCertificate)
    |> fetch_record_field(:OTPSubjectPublicKeyInfo)
    |> fetch_record_field(:RSAPublicKey)
  end

  defp fetch_record_field(record, key) do
    record |> Tuple.to_list() |> Enum.find(fn el -> is_tuple(el) && elem(el, 0) == key end)
  end
end
