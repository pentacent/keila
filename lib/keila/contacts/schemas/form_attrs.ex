defmodule Keila.Contacts.FormAttrs do
  use Keila.Schema, prefix: "f_attr"
  alias Keila.Contacts.Form

  @expiry_in_days 60

  schema "contacts_form_attrs" do
    field :attrs, :map
    field :expires_at, :utc_datetime
    belongs_to :form, Form, type: Form.Id
    timestamps()
  end

  def changeset(struct \\ %__MODULE__{}, form_id, attrs) do
    struct
    |> change()
    |> put_change(:form_id, form_id)
    |> put_change(:attrs, attrs)
    |> maybe_put_expires_at()
  end

  defp maybe_put_expires_at(changeset) do
    case get_field(changeset, :expires_at) do
      nil -> put_change(changeset, :expires_at, expires_at())
      _ -> changeset
    end
  end

  defp expires_at() do
    DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.add(@expiry_in_days, :day)
  end
end
