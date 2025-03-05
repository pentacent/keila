defmodule KeilaWeb.ApiFormController do
  use KeilaWeb, :controller
  use OpenApiSpex.ControllerSpecs
  alias Keila.Contacts
  alias Keila.Contacts.{Contact, Form, FormParams}
  alias KeilaWeb.Api.Schemas
  alias KeilaWeb.Api.Errors

  plug KeilaWeb.Api.Plugs.Authorization
  plug KeilaWeb.Api.Plugs.Normalization

  tags(["Forms"])

  operation(:index,
    summary: "Index forms",
    description: "Retrieve all forms from your project.",
    parameters: [],
    responses: [
      ok: {"Form response", "application/json", Schemas.Form.IndexResponse}
    ]
  )

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    forms =
      Contacts.get_project_forms(project_id(conn))
      |> then(fn forms ->
        count = Enum.count(forms)
        %Keila.Pagination{data: forms, page: 0, page_count: 1, count: count}
      end)

    render(conn, "forms.json", %{forms: forms})
  end

  operation(:create,
    summary: "Create Form",
    parameters: [],
    request_body: {"Form params", "application/json", Schemas.Form.Params},
    responses: [
      ok: {"Form response", "application/json", Schemas.Form.Response}
    ]
  )

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, _params) do
    params =
      conn.body_params.data
      |> put_field_settings()

    case Contacts.create_form(project_id(conn), params) do
      {:ok, form} -> render(conn, "form.json", %{form: form})
      {:error, changeset} -> Errors.send_changeset_error(conn, changeset)
    end
  end

  operation(:show,
    summary: "Show Form",
    parameters: [id: [in: :path, type: :string, description: "Form ID"]],
    responses: [
      ok: {"Form response", "application/json", Schemas.Form.Response}
    ]
  )

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{id: id}) do
    case Contacts.get_project_form(project_id(conn), id) do
      form = %Form{} -> render(conn, "form.json", %{form: form})
      nil -> Errors.send_404(conn)
    end
  end

  operation(:update,
    summary: "Update Form",
    parameters: [id: [in: :path, type: :string, description: "Form ID"]],
    request_body: {"Form params", "application/json", Schemas.Form.Params},
    responses: [
      ok: {"Form response", "application/json", Schemas.Form.Response}
    ]
  )

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{id: id}) do
    params = conn.body_params.data
    project_id = project_id(conn)

    with form = %Form{} <- Contacts.get_project_form(project_id, id),
         params <- put_field_settings(params),
         params <- put_settings_changeset(form, params),
         {:ok, form} <- Contacts.update_form(id, params) do
      render(conn, "form.json", %{form: form})
    else
      {:error, changeset} -> Errors.send_changeset_error(conn, changeset)
      nil -> Errors.send_404(conn)
    end
  end

  defp put_field_settings(params) do
    case params[:fields] do
      fields when is_list(fields) ->
        params |> Map.delete(:fields) |> Map.put(:field_settings, fields)

      _ ->
        params
    end
  end

  defp put_settings_changeset(form, params) do
    case params[:settings] do
      settings_params when is_map(settings_params) ->
        Map.update!(params, :settings, fn params ->
          form.settings
          |> Form.Settings.changeset(params)
          |> Ecto.Changeset.apply_changes()
          |> Map.from_struct()
        end)

      _ ->
        params
    end
  end

  operation(:delete,
    summary: "Delete Form",
    parameters: [id: [in: :path, type: :string, description: "Form ID"]],
    responses: %{
      204 => "Form was deleted successfully or didn’t exist."
    }
  )

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, %{id: id}) do
    Contacts.delete_project_forms(project_id(conn), [id])

    conn
    |> send_resp(:no_content, "")
  end

  operation(:submit,
    summary: "Submit Form",
    description: """
    Submits a form. This is particularly useful if you want to start the Double-Opt-In process
    from the API or want to take advantage of the validation of custom fields provided by forms.

    **Note:** Even if `captcha_required` is set to `true`, submitting a Form from the API never
    requires a CAPTCHA.
    """,
    parameters: [id: [in: :path, type: :string, description: "Campaign ID"]],
    request_body: {"Contact params", "application/json", Schemas.Contact.Params},
    responses: %{
      200 => {"Contact response", "application/json", Schemas.Contact.Response},
      202 => {"Double-Opt-In response", "application/json", Schemas.Form.DoubleOptInResponse}
    }
  )

  @spec submit(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def submit(conn, %{id: id}) do
    with form = %Form{} <- Contacts.get_project_form(project_id(conn), id),
         {:ok, result} <- Contacts.perform_form_action(form, conn.body_params.data) do
      case result do
        contact = %Contact{} ->
          conn
          |> put_view(KeilaWeb.ApiContactView)
          |> render("contact.json", %{contact: contact})

        %FormParams{} ->
          conn
          |> put_status(202)
          |> render("double_opt_in_required.json", %{})
      end
    else
      {:error, changeset} -> Errors.send_changeset_error(conn, changeset)
      nil -> Errors.send_404(conn)
    end
  end

  defp project_id(conn), do: conn.assigns.current_project.id
end
