defmodule Keila.Id do
  @moduledoc """
  Module for turning numerical IDs into Hashids.

  ## Configuration
  Hashid settings can be configured in Mix config.
      config :keila, Keila.Id,
        alphabet: "abcdefghijkmnpqrstuvw"
        salt: "foo"
        min_len: 6


  ## Usage
  Use in Ecto Schema modules like this:

      use Keila.Id, prefix: "u"

  ## Deprecation Notice
  Due to a bug in previous Keila versions, up to Keila 0.11.1, all generated
  hash IDs were encoded with a fixed salt rather than a salt based on runtime
  configuration.

  All IDs generated after the bug was fixed are prefixed with "n". IDs using the
  deprecated salt can still be decoded. This option will eventually be
  removed.
  """

  defmacro __using__(opts \\ []) do
    quote do
      defmodule Id do
        use Ecto.Type
        import Keila.Id

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

        @separator "_"

        def encode(id) do
          config =
            {:ok, "n" <> @prefix <> @separator <> Hashids.encode(cached_hashid_config(), id)}
        end

        def decode("n" <> @prefix <> @separator <> hashid) do
          case Hashids.decode(cached_hashid_config(), hashid) do
            {:ok, [id]} -> {:ok, id}
            _ -> :error
          end
        end

        def decode(@prefix <> @separator <> hashid) do
          case Hashids.decode(deprecated_hashid_config(), hashid) do
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

  def cached_hashid_config() do
    Agent.get(Keila.Id.Cache, & &1)
  end

  @spec hashid_config() :: Hashids.t()
  def hashid_config() do
    config = Application.get_env(:keila, Keila.Id)
    alphabet = config |> Keyword.fetch!(:alphabet)
    salt = config |> Keyword.get(:salt, "")
    min_len = config |> Keyword.fetch!(:min_len)

    Hashids.new(alphabet: alphabet, salt: salt, min_len: min_len)
  end

  @deprecated_salt "bF4QzDjqV"
  @spec deprecated_hashid_config() :: Hashids.t()
  def deprecated_hashid_config() do
    config = Application.get_env(:keila, Keila.Id)
    alphabet = config |> Keyword.fetch!(:alphabet)
    min_len = config |> Keyword.fetch!(:min_len)

    Hashids.new(alphabet: alphabet, salt: @deprecated_salt, min_len: min_len)
  end
end
