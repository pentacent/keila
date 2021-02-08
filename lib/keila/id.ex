defmodule Keila.Id do
  @moduledoc """
  Module for turning numerical IDs into Hashids.

  ## Configuration
  Hashid settings can be configured in Mix config.
      config :keila, :ids,
        alphabet: "abcdefghijkmnpqrstuvw"
        salt: "foo"
        min_len: 6


  ## Usage
  Use in Ecto Schema modules like this:

      use Keila.Id, prefix: "u"
  """

  defmacro __using__(opts \\ []) do
    quote do
      defmodule Id do
        use Ecto.Type

        @get fn key ->
          config = Application.get_env(:keila, :ids, [])
          value = unquote(opts) |> Keyword.get(key, Keyword.get(config, key))
          {key, value}
        end

        @hashids_config Hashids.new([@get.(:alphabet), @get.(:salt), @get.(:min_len)])

        @prefix Keyword.get_lazy(
                  unquote(opts),
                  :prefix,
                  fn ->
                    __MODULE__
                    |> to_string()
                    |> String.replace(~r{.Id$}, "")
                    |> String.replace(~r{^Elixir\.}, "")
                    |> String.downcase()
                  end
                )
        @separator Keyword.get(unquote(opts), :separator, "_")

        def encode(id) do
          {:ok, @prefix <> @separator <> Hashids.encode(@hashids_config, id)}
        end

        def decode(@prefix <> @separator <> hashid) do
          case Hashids.decode(@hashids_config, hashid) do
            {:ok, [id]} -> {:ok, id}
            _ -> :error
          end
        end

        def decode(_), do: :error

        @impl true
        def type, do: :integer

        @impl true
        def cast(id) when is_binary(id), do: {:ok, id}
        def cast(id) when is_integer(id), do: encode(id)
        def cast(_), do: :error

        @impl true
        def load(id) when is_integer(id) and id > 0, do: encode(id)
        def load(_), do: :error

        @impl true
        def dump(id), do: decode(id)
      end

      @type id :: binary() | integer()
      @primary_key {:id, Id, read_after_writes: true}
    end
  end
end
