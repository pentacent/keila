defmodule Keila.Contacts.FormActionHandler do
  @moduledoc """
  Module to handle the submission for a Form.
  """

  use Keila.Repo
  alias Keila.Contacts
  alias Keila.Contacts.Contact
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
    |> changeset_transform.()
    |> Repo.insert()
    |> case do
      {:ok, contact} ->
        {:ok, contact}

      {:error, changeset = %{errors: [double_opt_in: {"HMAC missing", _}]}} ->
        create_form_params_from_changeset(form, changeset)

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp create_form_params_from_changeset(form, changeset) do
    {:ok, form_params} = Contacts.create_form_params(form.id, changeset.changes)

    SendDoubleOptInMailWorker.new(%{"form_params_id" => form_params.id})
    |> Oban.insert()

    {:ok, form_params}
  end
end
