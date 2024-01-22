defmodule Keila.Contacts.FormActionHandler do
  @moduledoc """
  Module to handle the submission for a Form.
  """

  use Keila.Repo
  alias Keila.Contacts
  alias Keila.Contacts.Contact
  alias Keila.Contacts.EctoStringMap
  alias Keila.Contacts.FormParams
  alias Keila.Mailings.SendDoubleOptInMailWorker

  @doc """
  Creates a new Contact within the given Project with dynamic casts and
  validations based on the given form.

  If the Form settings specify that Double Opt-in is required for form contacts,
  creates a `FormParams` entity instead and sends the opt-in email.

  ## Options:
  - `:changeset_transform` - function to transform the changeset before
    `Repo.insert/1` is called. This is primarily used to add CAPTCHA checking
    from the controller layer
  """
  @spec perform_form_action(Form.t(), map()) ::
          {:ok, Contact.t() | FormParams.t()} | {:error, Changeset.t(Contact.t())}
  def perform_form_action(form, params, opts \\ []) do
    changeset_transform = Keyword.get(opts, :changeset_transform, & &1)

    params
    |> Contact.changeset_from_form(form)
    |> EctoStringMap.finalize_string_map(:data)
    |> changeset_transform.()
    |> Repo.insert()
    |> case do
      {:ok, contact} ->
        {:ok, contact}

      {:error, changeset = %{errors: [double_opt_in: {"HMAC missing", _}]}} ->
        create_form_params_from_changeset(form, changeset)

      {:error, changeset} ->
        {:error, postprocess_error_changeset(changeset, form)}
    end
  end

  defp create_form_params_from_changeset(form, changeset) do
    changes =
      Map.update(changeset.changes, :data, nil, fn
        changeset = %Ecto.Changeset{} -> apply_changes(changeset)
        other -> other
      end)

    {:ok, form_params} = Contacts.create_form_params(form.id, changes)

    SendDoubleOptInMailWorker.new(%{"form_params_id" => form_params.id})
    |> Oban.insert()

    {:ok, form_params}
  end

  # This function normalizes the error changeset to make sure the data field is
  # always passed as a changeset if there are changes.
  # This is necessary if there was a constraint error and the StringMap changeset
  # was unable to pick up the parent changeset error
  defp postprocess_error_changeset(changeset, form)

  defp postprocess_error_changeset(changeset = %{changes: %{data: %Ecto.Changeset{}}}, _),
    do: changeset

  defp postprocess_error_changeset(changeset = %{changes: %{data: %{}}}, form) do
    %{changes: changes} =
      changeset
      |> apply_changes()
      |> Map.from_struct()
      |> Contact.changeset_from_form(form)

    %{changeset | changes: changes}
  end

  defp postprocess_error_changeset(changeset, _), do: changeset
end
