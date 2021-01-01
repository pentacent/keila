defmodule Keila.Repo do
  use Ecto.Repo,
    otp_app: :keila,
    adapter: Ecto.Adapters.Postgres
end
