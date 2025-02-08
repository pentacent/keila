defmodule KeilaWeb.PutLocalePlug do
  @moduledoc """
  Plug for setting the Gettext locale.

  When the `:current_user` assign is available and has a locale set, the locale
  is taken from the user’s settings. Otherwise the locales from the
  `accept-language` header are used.
  """

  alias Keila.Auth.User

  @spec init(list()) :: list()
  def init(_), do: []

  @spec call(Plug.Conn.t(), list()) :: Plug.Conn.t()
  def call(conn, _opts) do
    case conn.assigns[:current_user] do
      %User{locale: locale} when is_binary(locale) ->
        put_locale(locale)
        conn

      _other ->
        put_locale_from_session(conn)
    end
  end

  defp put_locale(locale) do
    locales = Application.get_env(:keila, KeilaWeb.Gettext) |> Keyword.fetch!(:locales)

    if locale in locales do
      Gettext.put_locale(locale)
      :ok
    else
      :error
    end
  end

  defp put_locale_from_session(conn) do
    param_locale = conn.query_params["lang"]
    session_locale = Plug.Conn.get_session(conn, :locale)
    header_locales = get_header_locales(conn)

    locale =
      [param_locale, session_locale | header_locales]
      |> Enum.find(fn locale -> put_locale(locale) == :ok end)

    if not is_nil(param_locale) and param_locale == locale do
      Plug.Conn.put_session(conn, :locale, locale)
    else
      conn
    end
  end

  defp get_header_locales(conn) do
    conn
    |> Plug.Conn.get_req_header("accept-language")
    |> Enum.join(",")
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(fn language ->
      case String.split(language, ";q=") do
        [language] ->
          {language, 1.0}

        [language, quality] ->
          case Float.parse(quality) do
            {quality, _} -> {language, quality}
            :error -> {language, 1.0}
          end
      end
    end)
    |> Enum.sort_by(&elem(&1, 1), :desc)
    |> Enum.map(&elem(&1, 0))
  end
end
