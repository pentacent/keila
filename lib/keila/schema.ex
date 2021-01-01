defmodule Keila.Schema do
  @moduledoc """
  Convenience module for use in all schemas.

  `use Keila.Schema` inserts the following code:
      alias Ecto.Repo
      require Ecto.Query
      import Ecto.Query
      import Ecto.Changeset
      use Ecto.Schema
      use Keila.Id, unquote(opts)

      @type t :: %__MODULE__{}

  Options given are passed to `Keila.Id`.
  """
  defmacro __using__(opts) do
    quote do
      alias Ecto.Repo
      require Ecto.Query
      import Ecto.Query
      import Ecto.Changeset
      use Ecto.Schema
      use Keila.Id, unquote(opts)

      @type t :: %__MODULE__{}
    end
  end
end
