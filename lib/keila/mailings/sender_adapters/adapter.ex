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

      def update_changeset(changeset), do: changeset
      defoverridable update_changeset: 1

      def put_provider_options(email, _), do: email
      defoverridable put_provider_options: 2

      def configurable?, do: true
      defoverridable configurable?: 0

      def requires_verification?, do: false
      defoverridable requires_verification?: 0

      def from(sender) do
        {sender.from_name, sender.from_email}
      end

      defoverridable from: 1

      def reply_to(sender) do
        if is_nil(sender.reply_to_email) do
          nil
        else
          {sender.reply_to_name, sender.reply_to_email}
        end
      end

      defoverridable reply_to: 1
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
  @callback after_create(Sender.t()) :: :ok | {:error, term()} | {:action_required, Sender.t()}

  @doc """
  Callback after Sender update for adapter-specific actions.
  Update will be rolled back if error tuple is returned.
  """
  @callback after_update(Sender.t()) :: :ok | {:error, term()} | {:action_required, Sender.t()}

  @doc """
  Callback that allows the adapter to react to changes (e.g. resetting the verification status when the from_email changes).
  """
  @callback update_changeset(Ecto.Changeset.t()) :: Ecto.Changeset.t()

  @doc """
  Callback after Sender deletion for adapter-specific cleanup.
  Deletion will not be executed if error tuple is returned.
  """
  @callback before_delete(Sender.t()) :: :ok | {:error, term()}

  @doc """
  Returns true if this Sender adapter can be configured by the user.
  """
  @callback configurable?() :: boolean()

  @doc """
  Returns true if the sender requires verification of the from_email field.
  TODO: Right now, this is only implemented for the SWK adapter but should be extended to all adapters later.
  """
  @callback requires_verification?() :: boolean()

  @doc """
  Returns the sender's from address and name for `Swoosh.Email.from/2`.
  """
  @callback from(Sender.t()) :: Swoosh.Email.Recipient.t()

  @doc """
  Returns the sender's from address and name for `Swoosh.Email.reply_to/2`.
  Returns `nil` if no reply-to address is configured.
  """
  @callback reply_to(Sender.t()) :: Swoosh.Email.Recipient.t() | nil

  @doc """
  Optional callback for implementing a custom method of delivering the Sender verification email.
  """
  @callback deliver_verification_email(
              Sender.t(),
              token :: String.t(),
              url_fn :: (String.t() -> String.t())
            ) ::
              {:ok, Sender.t()} | {:error, term()}

  @doc """
  Optional callback for cleaning up after a successful verification.
  """
  @callback after_from_email_verification(Sender.t()) :: :ok

  @doc """
  Optional callback for implementing rate limits at the adapter level.
  Returns rate limit configuration as keyword list with units as keys
  and limits as values.

  Units must be sorted from largest to smallest.
  """
  @callback rate_limit(Sender.t() | SharedSender.t()) :: [
              {:hour | :minute | :second, non_neg_integer() | nil}
            ]

  @optional_callbacks [
    deliver_verification_email: 3,
    after_from_email_verification: 1,
    from: 1,
    reply_to: 1,
    rate_limit: 1
  ]
end
