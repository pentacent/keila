defmodule Keila.Mailings.SenderAdapters.Adapter do
  alias Keila.Mailings.Sender

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

      def before_delete(_), do: :ok
      defoverridable before_delete: 1

      def after_create(_), do: :ok
      defoverridable after_create: 1

      def after_update(_), do: :ok
      defoverridable after_update: 1

      def put_provider_options(email, _), do: email
      defoverridable put_provider_options: 2

      def verify_from_token(_, _), do: raise("Not implemented")
      defoverridable verify_from_token: 2

      def cancel_verification_from_token(_, _), do: raise("Not implemented")
      defoverridable cancel_verification_from_token: 2

      def only_shared?, do: false
      defoverridable only_shared?: 0
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
  @callback to_swoosh_config(Sender.t() | SharedSender.t()) :: keyword()

  @doc """
  Applies provider options to Swoosh email from the passed sender adapter configuration.
  """
  @callback put_provider_options(Swoosh.Email.t(), Sender.t() | SharedSender.t()) ::
              Swoosh.Email.t()

  @doc """
  This callback is invoked in a transaction after Sender creation.
  It can be used for adapter-specific actions, e.g. calling external APIs.
  Creation will be rolled back if error tuple is returned and the error is added
  to the `:config` attribute of the Sender changeset.
  """
  @callback after_create(Sender.t()) :: :ok | {:error, term()}

  @doc """
  Callback after Sender update for adapter-specific actions.
  Update will be rolled back if error tuple is returned.
  """
  @callback after_update(Sender.t()) :: :ok | {:error, term()}

  @doc """
  Callback after Sender deletion for adapter-specific cleanup.
  Deletion will not be executed if error tuple is returned.
  """
  @callback before_delete(Sender.t()) :: :ok | {:error, term()}

  @doc """
  Callback for handling a `"mailings.verify_sender"` token.
  When creating this token in one of the other callbacks,
  make sure to include the attribute `"sender_id"` and `"type"`
  for the Sender ID and the Adapter name respectively.
  """
  @callback verify_from_token(Sender.t(), Token.t()) :: {:ok, Sender.t()} | {:error, term()}

  @doc """
  Callback for canceling the verification of a `"mailings.verify_sender"` token.
  """
  @callback cancel_verification_from_token(Sender.t(), Token.t()) :: :ok

  @doc """
  Returns true if this Sender adapter is only available as a shared sender.
  """
  @callback only_shared?() :: boolean()
end
