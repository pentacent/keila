defmodule Keila.Mailings.TransactionalMessage.Request do
  @moduledoc """
  Transient data structure that represents the data from which a `Message`
  can be created by the `TransactionalMessage` module.

  A request consists of delivery parameters (recipient, sender, cc/bcc,
  assigns) and email content, which is cast into a `Keila.Mailings.Email`
  struct in the virtual `email` field.
  Both delivery parameters and email content parameters must be provided as
  a flat `params` map. `Email` changeset errors are merged back into the
  `Request` changeset.
  """

  use Ecto.Schema
  import Ecto.Changeset
  alias Keila.Mailings.Email

  @primary_key false
  embedded_schema do
    field :recipient_email, :string
    field :recipient_name, :string
    field :contact_id, :string
    field :external_contact_id, :string
    field :contact, :map, virtual: true

    field :cc, {:array, :string}
    field :bcc, {:array, :string}

    field :assigns, :map

    field :sender_id, :string
    field :sender, :map, virtual: true

    field :email, :map, virtual: true
  end

  @type t :: %__MODULE__{}

  @cast_fields [
    :recipient_email,
    :recipient_name,
    :contact_id,
    :external_contact_id,
    :assigns,
    :sender_id
  ]

  @recipient_fields [:contact_id, :external_contact_id, :recipient_email]
  @supported_types [:text, :html, :mjml]

  def changeset(params, project_id) do
    %__MODULE__{}
    |> cast(params, @cast_fields)
    |> cast_addresses(params, :cc)
    |> cast_addresses(params, :bcc)
    |> validate_required([:sender_id])
    |> validate_one_of(@recipient_fields)
    |> Keila.EmailAddress.validate_email(:recipient_email)
    |> cast_email(params, project_id)
  end

  defp cast_email(changeset, params, project_id) do
    email_changeset = Email.creation_changeset(%Email{}, params, project_id)

    changeset
    |> put_change(:email, apply_changes(email_changeset))
    |> merge_errors(email_changeset)
    |> validate_email_type(email_changeset)
  end

  defp merge_errors(changeset, %Ecto.Changeset{errors: errors}) do
    Enum.reduce(errors, changeset, fn {field, {message, opts}}, changeset ->
      add_error(changeset, field, message, opts)
    end)
  end

  defp validate_email_type(changeset, email_changeset) do
    case get_field(email_changeset, :type) do
      nil -> changeset
      type when type in @supported_types -> changeset
      _other -> add_error(changeset, :type, "is not supported")
    end
  end

  # `cc`/`bcc` accept either a single RFC 5322 address-list string or a list of
  # such strings; normalize both to a list of canonical mailbox strings.
  defp cast_addresses(changeset, params, field) do
    case fetch_param(params, field) do
      :error ->
        changeset

      {:ok, value} ->
        case Keila.EmailAddress.to_mailbox_strings(value) do
          {:ok, addresses} -> put_change(changeset, field, addresses)
          :error -> add_error(changeset, field, "has an invalid address")
        end
    end
  end

  defp fetch_param(params, field) do
    case Map.fetch(params, Atom.to_string(field)) do
      {:ok, value} -> {:ok, value}
      :error -> Map.fetch(params, field)
    end
  end

  defp validate_one_of(changeset, fields) do
    if Enum.any?(fields, &get_field(changeset, &1)) do
      changeset
    else
      add_error(
        changeset,
        hd(fields),
        "one of #{Enum.map_join(fields, ", ", &Atom.to_string/1)} is required"
      )
    end
  end
end
