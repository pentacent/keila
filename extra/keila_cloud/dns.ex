require Keila

Keila.if_cloud do
  defmodule KeilaCloud.DNS do
    @doc """
    Looks up the value of a DNS entry and returns it as `{:ok, value}`.
    If there is no entry, returns `nil`.
    If the lookup failed or if there are multiple entries, returns `:error`.
    """
    @spec lookup(String.t(), String.t(), :cname | :txt) :: {:ok, String.t()} | nil | :error
    def lookup(domain, subdomain, type)
        when is_binary(domain) and is_binary(subdomain) and type in [:cname, :txt] do
      "#{subdomain}.#{domain}"
      |> String.to_charlist()
      |> :inet_res.lookup(:in, type)
      |> case do
        [entry] when is_list(entry) -> {:ok, to_string(entry)}
        [] -> nil
        _other -> :error
      end
    end

    @doc """
    Returns `true` if the given string is a valid DMARC string, else returns `false`.
    """
    @spec valid_dmarc?(String.t()) :: boolean()
    def valid_dmarc?("v=DMARC1;" <> _ = raw_dmarc_tags) do
      dmarc_tags =
        raw_dmarc_tags
        |> String.split(";")
        |> Enum.map(&String.trim/1)

      Enum.all?(dmarc_tags, &String.contains?(&1, "=")) and
        Enum.any?(dmarc_tags, &String.starts_with?(&1, "p="))
    end

    def valid_dmarc?(_), do: false
  end
end
