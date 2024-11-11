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

    maybe_get_existing_contact(form, params)
    |> Contact.changeset_from_form(params, form)
    |> EctoStringMap.finalize_string_map(:data)
    |> changeset_transform.()
    |> Repo.insert_or_update()
    |> case do
      {:ok, contact} ->
        {:ok, contact}

      {:error, changeset = %{errors: [double_opt_in: {"HMAC missing", _}]}} ->
        create_form_params_from_changeset(form, changeset)

      {:error, changeset} ->
        {:error, postprocess_error_changeset(changeset, form)}
    end
  end

  defp maybe_get_existing_contact(form, params) do
    email = params["email"] || params[:email]

    (email && Contacts.get_project_contact_by_email(form.project_id, email)) || %Contact{}
  end

  defp create_form_params_from_changeset(form, changeset = %{errors: [double_opt_in: _]}) do
    changeset =
      %{changeset | valid?: true, errors: []}
      |> EctoStringMap.finalize_string_map(:data)

    {:ok, form_params} = Contacts.create_form_params(form.id, changeset.changes)

    SendDoubleOptInMailWorker.new(%{"form_params_id" => form_params.id})
    |> Oban.insert()

    {:ok, form_params}
  end

  # This function normalizes the error changeset to make sure the data field is
  # always passed as a changeset if there are changes.
  # This is necessary if there was a constraint error and the StringMap changeset
  # was unable to pick up the parent changeset error
  #
  # The function also sanitizes the changeset by resetting the `data` key in order to
  # avoid leaking existing contact information.
  defp postprocess_error_changeset(changeset, form)

  defp postprocess_error_changeset(changeset = %{changes: %{data: %Ecto.Changeset{}}}, _),
    do: %{changeset | action: :insert, data: %Contact{}}

  defp postprocess_error_changeset(changeset = %{changes: %{data: %{}}}, form) do
    %{changes: changes} =
      changeset
      |> apply_changes()
      |> Map.from_struct()
      |> Contact.changeset_from_form(form)

    %{changeset | changes: changes, data: %Contact{}, action: :insert}
  end

  defp postprocess_error_changeset(changeset, _), do: changeset
end
