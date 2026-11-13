defmodule Keila.Contacts.FormParams do
  @moduledoc """
  FormParams hold the parameters for a `Keila.Contacts.Form` to be submitted
  again after a double opt-in process.
  """
  use Keila.Schema, prefix: "f_attr"
  alias Keila.Contacts.Form

  schema "contacts_form_params" do
    field :params, :map
    field :expires_at, :utc_datetime
    belongs_to :form, Form, type: Form.Id
    timestamps()
  end

  def changeset(struct \\ %__MODULE__{}, form_id, params) do
    struct
    |> change()
    |> put_change(:form_id, form_id)
    |> put_change(:params, params)
    |> maybe_put_expires_at()
  end

  defp maybe_put_expires_at(changeset) do
    case get_field(changeset, :expires_at) do
      nil -> put_change(changeset, :expires_at, expires_at())
      _ -> changeset
    end
  end

  defp expires_at() do
    DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.add(retention_days(), :day)
  end

  @doc """
  Returns the number of days FormParams are retained, configured via
  the `DOUBLE_OPT_IN_RETENTION_DAYS` environment variable.
  """
  @spec retention_days() :: pos_integer()
  def retention_days() do
    Application.get_env(:keila, Keila.Contacts) |> Keyword.fetch!(:double_opt_in_retention_days)
  end
end
