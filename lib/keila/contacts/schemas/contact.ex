defmodule Keila.Contacts.Contact do
  use Keila.Schema, prefix: "c"
  alias Keila.Contacts.EctoStringMap
  alias Keila.Contacts.Form

  @statuses Enum.with_index([
              :active,
              :unsubscribed,
              :unreachable
            ])

  schema "contacts" do
    field(:email, :string)
    field(:external_id, :string)
    field(:first_name, :string)
    field(:last_name, :string)
    field(:status, Ecto.Enum, values: @statuses, default: :active)
    field(:data, Keila.Repo.JsonField)
    field(:double_opt_in_at, :utc_datetime)
    belongs_to(:project, Keila.Projects.Project, type: Keila.Projects.Project.Id)
    timestamps()
  end

  @spec creation_changeset(t(), Ecto.Changeset.data(), Keila.Projects.Project.id(), Keyword.t()) ::
          Ecto.Changeset.t(t())
  def creation_changeset(struct \\ %__MODULE__{}, params, project_id, opts \\ []) do
    struct
    |> cast(params, [:email, :external_id, :first_name, :last_name, :project_id, :data])
    |> put_change(:project_id, project_id)
    |> validate_email()
    |> validate_max_name_length()
    |> validate_external_id()
    |> check_data_size_constraint()
  end

  @spec update_status_changeset(t() | Ecto.Changeset.t(t()), Ecto.Changeset.data()) ::
          Ecto.Changeset.t(t())
  def update_status_changeset(struct \\ %__MODULE__{}, params) do
    changeset = struct
    |> cast(params, [:status])
    
    # Force status to be included in changeset if it was present in params
    # This is needed because Ecto won't include it if it's the same as the default value
    changeset = if Map.has_key?(params, :status) and not Map.has_key?(changeset.changes, :status) do
      put_change(changeset, :status, params[:status])
    else
      changeset
    end

    changeset
    |> normalize_status([])
  end

  @spec update_changeset(t(), Ecto.Changeset.data()) :: Ecto.Changeset.t(t())
  def update_changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:email, :external_id, :first_name, :last_name, :data])
    |> validate_email()
    |> validate_max_name_length()
    |> validate_external_id()
    |> check_data_size_constraint()
    |> maybe_remove_double_opt_in_at()
  end

  @spec changeset_from_form(t(), Ecto.Changeset.data(), Form.t()) :: Ecto.Changeset.t(t())
  def changeset_from_form(struct \\ %__MODULE__{}, params, form) do
    form_params_id = get_param(params, :form_params_id)
    double_opt_in_hmac = get_param(params, :double_opt_in_hmac)

    cast_fields =
      form.field_settings
      |> Enum.filter(&(&1.cast and &1.field != :data))
      |> Enum.map(& &1.field)

    required_fields =
      form.field_settings
      |> Enum.filter(&(&1.field != :data and &1.cast and &1.required))
      |> Enum.map(& &1.field)

    data_field_definitions =
      form.field_settings
      |> Enum.filter(&(&1.field == :data and &1.cast))
      |> Enum.map(&EctoStringMap.FieldDefinition.from_field_settings/1)

    field_mapping =
      EctoStringMap.build_field_mapping(data_field_definitions)

    struct
    |> cast(params, cast_fields)
    |> validate_dynamic_required(required_fields)
    |> validate_email()
    |> validate_max_name_length()
    |> validate_double_opt_in(form, form_params_id, double_opt_in_hmac)
    |> put_change(:project_id, form.project_id)
    |> put_change(:status, :active)
    |> EctoStringMap.cast_string_map(:data, field_mapping)
  end

  defp get_param(params, param) do
    params[param] || params[to_string(param)]
  end

  defp validate_dynamic_required(changeset, required_fields)
  defp validate_dynamic_required(changeset, []), do: changeset
  defp validate_dynamic_required(changeset, fields), do: validate_required(changeset, fields)

  defp check_data_size_constraint(changeset) do
    changeset
    |> check_constraint(:data, name: :max_data_size, message: "max 8 KB data allowed")
  end

  @email_regex ~r/^[^\s@]+@[^\s@]+$/
  defp validate_email(changeset) do
    changeset
    |> validate_required([:email])
    |> update_change(:email, fn email ->
      if is_binary(email), do: String.trim(email)
    end)
    |> validate_format(:email, @email_regex, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 255)
    |> unique_constraint([:email, :project_id])
  end

  defp maybe_remove_double_opt_in_at(changeset) do
    changed_email = get_change(changeset, :email)
    current_email = changeset.data.email

    if not is_nil(changed_email) and not is_nil(current_email) and changed_email != current_email do
      put_change(changeset, :double_opt_in_at, nil)
    else
      changeset
    end
  end

  defp validate_double_opt_in(changeset, %{settings: %{double_opt_in_required: false}}, _, _),
    do: changeset

  defp validate_double_opt_in(changeset, form, form_params_id, hmac)
       when is_binary(form_params_id) and is_binary(hmac) do
    if Keila.Contacts.valid_double_opt_in_hmac?(hmac, form.id, form_params_id) do
      put_change(changeset, :double_opt_in_at, DateTime.utc_now(:second))
    else
      add_error(changeset, :double_opt_in, "Invalid HMAC")
    end
  end

  defp validate_double_opt_in(changeset, _, _, _) do
    add_error(changeset, :double_opt_in, "HMAC missing")
  end

  defp validate_max_name_length(changeset) do
    changeset
    |> validate_length(:first_name, max: 50)
    |> validate_length(:last_name, max: 50)
  end

  defp validate_external_id(changeset) do
    changeset
    |> validate_length(:external_id, max: 40)
    |> unique_constraint([:external_id, :project_id])
  end

  defp normalize_status(changeset, opts) do
    case get_change(changeset, :status) do
      nil ->
        changeset
      status when is_binary(status) ->
        trimmed_status = String.trim(status)

        case String.downcase(trimmed_status) do
          "" ->
            # Empty status defaults to active
            handle_valid_status(changeset, :active, trimmed_status, opts)
          "active" ->
            handle_valid_status(changeset, :active, trimmed_status, opts)
          "unsubscribed" ->
            handle_valid_status(changeset, :unsubscribed, trimmed_status, opts)
          "unreachable" ->
            handle_valid_status(changeset, :unreachable, trimmed_status, opts)
          _invalid_status ->
            # Add validation error for invalid status
            add_error(changeset, :status, "must be one of: active, unsubscribed, unreachable")
        end

      status when is_atom(status) ->
        changeset
    end
  end

  defp handle_valid_status(changeset, normalized_status, trimmed_status, opts) do
    # Check if this is an update that would downgrade status (reactivate unsubscribed/unreachable)
    # Only prevent if the status was empty (not explicitly set to "active")
    current_status = get_field(changeset, :status)

    if should_prevent_status_downgrade?(current_status, normalized_status, trimmed_status, opts) do
      # Don't change the status if it would be a downgrade and wasn't explicit
      # Remove the status change entirely so the existing value is preserved
      Map.update!(changeset, :changes, &Map.delete(&1, :status))
    else
      # Use force_change to ensure the status is included even if it's the same as the current value
      force_change(changeset, :status, normalized_status)
    end
  end

  # Prevent reactivating contacts that are unsubscribed or unreachable ONLY if status was empty
  # If someone explicitly sets status to "active", allow the reactivation
  defp should_prevent_status_downgrade?(_current_status, new_status, original_status_string, opts) do
    # If explicit reactivation is allowed via opts, don't prevent
    if Keyword.get(opts, :allow_reactivation, false) do
      false
    else
      # During import, current_status might be empty string or nil because we're creating a changeset from scratch
      # We should only prevent reactivation if the new status would be :active and the original was empty
      # This logic assumes that if someone imports with empty status, they don't want to change the existing status
      case {new_status, original_status_string} do
        {:active, ""} -> true  # Empty status trying to set to active - prevent this (preserve existing status)
        _ -> false  # Allow all other changes, including explicit "active", "unsubscribed", etc.
      end
    end
  end
end
