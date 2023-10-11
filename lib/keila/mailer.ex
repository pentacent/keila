defmodule Keila.Mailer do
  use Swoosh.Mailer, otp_app: :keila
  alias Keila.Mailings.Sender
  alias Keila.Mailings.SharedSender

  @doc """
  Delivers an email using the configured system mailer.
  """
  @spec deliver_system_email!(Swoosh.Email.t()) :: term()
  def deliver_system_email!(email) do
    config =
      Application.get_env(:keila, __MODULE__)
      |> maybe_put_tls_opts()

    deliver!(email, config)
  end

  defp maybe_put_tls_opts(config) do
    if Keyword.get(config, :ssl) do
      Keyword.put(config, :sockopts, :tls_certificate_check.options(config[:relay]))
    else
      config
    end
  end

  @doc """
  Delivers an email using a given sender.
  """
  @spec deliver_with_sender(Swoosh.Email.t(), Sender.t() | SharedSender.t()) ::
          {:error, term()} | {:ok, term()}
  def deliver_with_sender(email, sender) do
    adapter = Keila.Mailings.SenderAdapters.get_adapter(sender.config.type)

    config =
      sender
      |> adapter.to_swoosh_config()
      |> Enum.filter(fn {_, v} -> not is_nil(v) end)

    try do
      email
      |> adapter.put_provider_options(sender)
      |> deliver(config)
    rescue
      e -> {:error, e}
    end
  end

  @doc """
  Checks the rate limit of a Sender. If the sender is using a shared
  sender, the `:shared_sender` association must be preloaded.

  Returns `:ok` if rate limit has not been exceeded or
  `{:error, seconds_to_next_bucket}` otherwise.

  `seconds_to_next_bucket` is the time until the rate limit that was exceeded
  is reset.
  """
  @spec check_sender_rate_limit(Sender.t()) :: :ok | {:error, integer()}
  def check_sender_rate_limit(sender) do
    sender = sender.shared_sender || sender

    rate_limits = get_rate_limits(sender)

    with :ok <- precheck_rate_limits(rate_limits) do
      check_rate_limits(rate_limits)
    end
  end

  defp get_rate_limits(%Sender{shared_sender: %SharedSender{} = shared_sender}) do
    get_rate_limits(shared_sender)
  end

  # List rate limits with larger scale first
  defp get_rate_limits(sender) do
    [
      {:hour, sender.config.rate_limit_per_hour, bucket_name(sender, :hour)},
      {:minute, sender.config.rate_limit_per_minute, bucket_name(sender, :minute)},
      {:second, sender.config.rate_limit_per_second, bucket_name(sender, :second)}
    ]
  end

  # Inspect buckets to see if buckets with large scales have already been exhausted
  defp precheck_rate_limits(rate_limits) do
    rate_limits
    |> Enum.filter(fn {scale_name, _, _} -> scale_name != :second end)
    |> Enum.reduce_while(:ok, fn rate_limit, :ok ->
      case do_precheck_rate_limit(rate_limit) do
        :ok -> {:cont, :ok}
        {:error, seconds_to_next_bucket} -> {:halt, {:error, seconds_to_next_bucket}}
      end
    end)
  end

  # Check rate limits in reversed order (starting with smaller scales)
  defp check_rate_limits(rate_limits) do
    rate_limits
    |> Enum.reverse()
    |> Enum.reduce_while(:ok, fn rate_limit, :ok ->
      case do_check_rate_limit(rate_limit) do
        :ok -> {:cont, :ok}
        {:error, seconds_to_next_bucket} -> {:halt, {:error, seconds_to_next_bucket}}
      end
    end)
  end

  defp do_precheck_rate_limit({scale_name, limit, bucket}) when is_integer(limit) and limit > 0 do
    scale = scale(scale_name)

    {_, remaining, ms_to_next_bucket, _, _} = ExRated.inspect_bucket(bucket, scale, limit)

    if remaining == 0 do
      seconds_to_next_bucket = max(1, div(ms_to_next_bucket, 1000))
      {:error, seconds_to_next_bucket}
    else
      :ok
    end
  end

  defp do_precheck_rate_limit(_), do: :ok

  defp do_check_rate_limit({scale_name, limit, bucket}) when is_integer(limit) and limit > 0 do
    scale = scale(scale_name)

    case ExRated.check_rate(bucket, scale, limit) do
      {:ok, _} ->
        :ok

      {:error, _} ->
        {_, _, ms_to_next_bucket, _, _} = ExRated.inspect_bucket(bucket, scale, limit)
        seconds_to_next_bucket = max(1, div(ms_to_next_bucket, 1000))
        {:error, seconds_to_next_bucket}
    end
  end

  defp do_check_rate_limit(_), do: :ok

  defp bucket_name(sender, scale_name) do
    "sender-bucket-per-#{scale_name}-#{sender.id}"
  end

  defp scale(scale_name)
  defp scale(:second), do: 1_000
  defp scale(:minute), do: 60_000
  defp scale(:hour), do: 3_600_000
end
