# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#

require Logger
alias Keila.{Repo, Auth}

if Keila.Repo.all(Auth.Group) == [] do
  Keila.Repo.insert!(%Auth.Group{name: "root"})
else
  Logger.info("Database already populated, not populating database.")
end
