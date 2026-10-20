defmodule Keila.Mailings.PublicUrl do
  defp put_if_not_empty(enumerable, key, value) when value not in [nil, ""] do
    Map.put(enumerable, key, value)
  end

  defp put_if_not_empty(enumerable, _key, _value) do
    enumerable
  end

  def is_public_url(url) do
    public_url_config = Application.get_env(:keila, :public_url)

    String.starts_with?(
      url,
      %URI{
        scheme: public_url_config[:scheme],
        host: public_url_config[:host],
        port: public_url_config[:port],
        path: public_url_config[:path]
      }
      |> URI.to_string()
    )
  end

  @spec convert_url_to_public_url(String.t()) :: String.t()
  def convert_url_to_public_url(url) do
    public_url_config = Application.get_env(:keila, :public_url)
    web_app_path = Application.get_env(:keila, KeilaWeb.Endpoint)[:url][:path]

    url
    |> URI.new!()
    |> put_if_not_empty(:scheme, public_url_config[:scheme])
    |> put_if_not_empty(:host, public_url_config[:host])
    |> put_if_not_empty(:port, public_url_config[:port])
    |> Map.update!(:path, fn v ->
      if web_app_path not in [nil, ""] do
        String.replace(v, web_app_path, "")
      else
        v
      end
    end)
    |> Map.update!(:path, fn v -> String.replace(v, "//", "/") end)
    |> Map.update!(:path, fn v ->
      URI.append_path(%URI{path: public_url_config[:path]}, v).path
    end)
    |> URI.to_string()
  end
end
