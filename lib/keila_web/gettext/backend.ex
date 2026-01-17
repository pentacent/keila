defmodule KeilaWeb.Gettext.Backend do
  use Gettext.Backend, otp_app: :keila, default_locale: "en", priv: "priv/gettext"

  @impl true
  defdelegate available_locales(), to: KeilaWeb.Gettext
end
