defmodule Keila.Auth.Event do
  @moduledoc """
  Schema for storing auth events like login attempts and password changes.

  `user_id` is the affected user. When the event is triggered by another
  authenticated user, `actor_id` may be set to reflect this.

  Events are deleted after a configurable retention period (see `Keila.Auth.prune_events/1`).
  """
  use Keila.Schema, prefix: "ae"
  alias Keila.Auth

  @types [
    :register,
    :resend_activation,
    :login,
    :login_failed,
    :logout,
    :request_password_reset,
    :reset_password,
    :change_password,
    :create_api_key,
    :delete_api_key,
    :authenticate_api_failed,
    :impersonate
  ]

  schema "auth_events" do
    field(:type, Ecto.Enum, values: @types)
    belongs_to(:user, Auth.User, type: Auth.User.Id)
    belongs_to(:actor, Auth.User, type: Auth.User.Id)
    field(:ip, Keila.Repo.IpAddress)
    field(:data, :map)

    timestamps(updated_at: false)
  end

  @doc """
  Returns all auth event types.
  """
  @spec types() :: [atom()]
  def types, do: @types

  @doc """
  Guard that checks whether `type` is a valid auth event type.
  """
  defguard is_type(type) when type in @types

  @creation_fields [:type, :user_id, :actor_id, :ip, :data]

  @spec creation_changeset(map()) :: Ecto.Changeset.t(t())
  def creation_changeset(params) do
    %__MODULE__{}
    |> cast(params, @creation_fields)
    |> validate_required([:type])
  end
end
