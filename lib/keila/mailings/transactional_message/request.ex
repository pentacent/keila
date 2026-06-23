defmodule Keila.Mailings.TransactionalMessage.Request do
  @moduledoc """
  Transient data structure that represents the data from which a `Message`
  can be created by the `TransactionalMessage` module.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :type, Ecto.Enum, values: [:text, :markdown, :block, :mjml, :html]

    field :subject, :string

    field :recipient_email, :string
    field :recipient_name, :string
    field :contact_id, :string
    field :external_contact_id, :string
    field :contact, :map, virtual: true

    field :cc, {:array, :string}
    field :bcc, {:array, :string}

    field :text_body, :string
    field :html_body, :string
    field :json_body, :map
    field :mjml_body, :string

    field :mjml_content, :map
    field :html_content, :map
    field :text_content, :map

    field :assigns, :map

    field :template_id, :string
    field :template, :map, virtual: true
    field :sender_id, :string
    field :sender, :map, virtual: true
  end

  @type t :: %__MODULE__{}

  @cast_fields [
    :type,
    :recipient_email,
    :recipient_name,
    :contact_id,
    :external_contact_id,
    :subject,
    :text_body,
    :html_body,
    :json_body,
    :mjml_body,
    :mjml_content,
    :html_content,
    :text_content,
    :assigns,
    :template_id,
    :sender_id
  ]

  @recipient_fields [:contact_id, :external_contact_id, :recipient_email]
  @body_fields %{text: :text_body, html: :html_body, mjml: :mjml_body}

  def changeset(params) do
    %__MODULE__{}
    |> cast(params, @cast_fields)
    |> cast_addresses(params, :cc)
    |> cast_addresses(params, :bcc)
    |> validate_required([:type, :sender_id])
    |> validate_inclusion(:type, [:text, :html, :mjml], message: "is not supported")
    |> validate_one_of(@recipient_fields)
    |> validate_body_source()
    |> Keila.EmailAddress.validate_email(:recipient_email)
  end

  # A message needs a body for its `type`, supplied directly or via a referenced
  # template. The template's actual contents are only known at render time, so
  # here we just require that one of the two sources is present.
  defp validate_body_source(changeset) do
    case @body_fields[get_field(changeset, :type)] do
      nil ->
        changeset

      body_field ->
        if present?(get_field(changeset, body_field)) or
             present?(get_field(changeset, :template_id)) do
          changeset
        else
          add_error(changeset, body_field, "can't be blank without a template")
        end
    end
  end

  defp present?(value), do: is_binary(value) and value != ""

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
