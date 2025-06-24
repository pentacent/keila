defmodule Keila.Cldr do
  use Cldr,
    otp_app: :keila,
    locales: Application.compile_env(:keila, KeilaWeb.Gettext)[:locales],
    default_locale: "en",
    providers: [Cldr.Territory]
end
