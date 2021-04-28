defmodule Keila.Mailings.SenderAdapters.Adapter do
  @moduledoc """
  Defines a sender adapter.

  Sender adapters are used by Keila to support sending campaings through various services.

  `schema_fields/0` defines configuration fields which will dynamically be added to the `Keila.Mailings.Sender.Config` schema.

  `changeset/2` will be used to build a changeset for the configuration fields
  before storing them in a `Keila.Mailings.Sender.Config` schema.

  `to_swoosh_config/1` retrieves configuration fields from
   `Keila.Mailings.Sender.Config` and builds the config that is passed to `Swoosh`.

  ## Example
      defmodule Sendgrid do
        use Keila.Mailings.SenderAdapters.Adapter

        @impl true
        def name, do: "sendgrid"

        @impl true
        def schema_fields do
          [
            sendgrid_api_key: :string
          ]
        end

        @impl true
        def changeset(changeset, params) do
          changeset
          |> cast(params, [:sendgrid_api_key])
          |> validate_required([:sendgrid_api_key])
        end

        @impl true
        def to_swoosh_config(sender) do
          [
            adapter: Swoosh.Adapters.Sendgrid,
            api_key: sender.config.sendgrid_api_key
          ]
        end
      end

  ## Configuration
      config :keila, Keila.Mailings.SenderAdapters, adapters: [NewSenderAdapter]
  """

  defmacro __using__(_options) do
    quote do
      @behaviour unquote(__MODULE__)
      import Ecto.Changeset
      alias Keila.Mailings.Sender
      alias unquote(__MODULE__)
    end
  end

  @type t :: module

  @doc """
  Returns the name of the sender adapter.
  """
  @callback name() :: String.t()

  @doc """
  Returns a list of Ecto schema fields required by the adapter.
  """
  @callback schema_fields() :: keyword(atom())

  @doc """
  Builds a changeset for the sender adapter configuration.
  """
  @callback changeset(
              Ecto.Changeset.t(),
              %{optional(String.t()) => term()} | %{optional(atom()) => term()}
            ) :: Ecto.Changeset.t()

  @doc """
  Builds a swoosh config from the passed sender adapter configuration.
  """
  @callback to_swoosh_config(Keila.Mailings.Sender.t()) :: keyword()
end
