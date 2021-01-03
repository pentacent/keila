import Config

update_env = fn app, key, update_fn ->
  value = update_fn.(Application.get_env(app, key))
  Application.put_env(app, key, value)
end

if config_env() == :prod do
end

if config_env() == :test do
  db_url = System.get_env("DB_URL")

  if db_url do
    db_url = db_url <> "#{System.get_env("MIX_TEST_PARTITION")}"
    update_env.(:keila, Keila.Repo, &Keyword.replace(&1, :url, db_url))
  end

  # username: "postgres",
  # password: "postgres-keila-dev-pw",
  # database: "keila_test#{System.get_env("MIX_TEST_PARTITION")}",
  # hostname: "localhost",
  # port: 54323,
end
