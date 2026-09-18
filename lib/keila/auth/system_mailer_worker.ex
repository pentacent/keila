defmodule Keila.Auth.SystemMailerWorker do
  @moduledoc """
  Oban worker for sending system emails with `Keila.Auth.Emails`.
  """

  use Oban.Worker, queue: :system_mailer, max_attempts: 5
  alias Keila.Auth.Emails

  @impl true
  def perform(%Oban.Job{args: args}) do
    %{"email" => email, "locale" => locale, "params" => params} = args
    Gettext.put_locale(locale)

    with {:ok, params} <- deserialize_params(params) do
      email
      |> String.to_existing_atom()
      |> Emails.send!(Map.put(params, :token_params, args["token_params"]))

      :ok
    end
  end

  defp deserialize_params(params) do
    Enum.reduce_while(params, {:ok, %{}}, fn param, {:ok, acc} ->
      case deserialize_param(param) do
        {:cancel, reason} -> {:halt, {:cancel, reason}}
        {key, value} -> {:cont, {:ok, Map.put(acc, key, value)}}
      end
    end)
  end

  defp deserialize_param({"user_id", user_id}) do
    case Keila.Auth.get_user(user_id) do
      nil -> {:cancel, :user_not_found}
      user -> {:user, user}
    end
  end

  defp deserialize_param({key, value}), do: {String.to_existing_atom(key), value}
end
