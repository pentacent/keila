defmodule KeilaWeb.ApiContactController do
  use KeilaWeb, :controller
  use OpenApiSpex.ControllerSpecs
  alias Keila.Contacts
  alias KeilaWeb.Api.Schemas
  alias KeilaWeb.Api.Errors

  plug KeilaWeb.Api.Plugs.Authorization
  plug KeilaWeb.Api.Plugs.Normalization

  # Open API Tags
  tags(["Contacts"])

  operation(:index,
    summary: "Index contacts",
    description: "Retrieve contacts from your project with support for pagination and filtering.",
    parameters: [
      paginate: [
        in: :query,
        style: :deepObject,
        description: "Pagination",
        schema: %OpenApiSpex.Schema{
          type: :object,
          properties: %{
            page: %OpenApiSpex.Schema{type: :integer, example: 0},
            page_size: %OpenApiSpex.Schema{type: :integer, example: 50}
          }
        }
      ],
      filter: [
        in: :query,
        description: "Contact query as JSON string.",
        example: %{"email" => %{"$like" => "%keila.io"}} |> Jason.encode!(),
        schema: %OpenApiSpex.Schema{
          type: :string,
          "x-validate": KeilaWeb.Api.ContactFilterValidator
        }
      ]
    ],
    responses: [
      ok: {"Contact index response", "application/json", Schemas.Contact.IndexResponse}
    ]
  )

  @spec index(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def index(conn, params) do
    paginate =
      params
      |> Map.get(:paginate, %{})
      |> Map.put_new(:page, 0)
      |> Map.put_new(:page_size, 50)
      |> Map.to_list()

    filter = Map.get(params, :filter, %{})

    contacts =
      Contacts.get_project_contacts(project_id(conn),
        paginate: paginate,
        filter: filter
      )

    render(conn, "contacts.json", %{contacts: contacts})
  end

  operation(:create,
    summary: "Create Contact",
    parameters: [],
    request_body: {"Contact params", "application/json", Schemas.Contact.CreateParams},
    responses: [
      ok: {"Contact response", "application/json", Schemas.Contact.Response}
    ]
  )

  @spec create(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def create(conn, _params) do
    case Contacts.create_contact(project_id(conn), conn.body_params.data, set_status: true) do
      {:ok, contact} -> render(conn, "contact.json", %{contact: contact})
      {:error, changeset} -> Errors.send_changeset_error(conn, changeset)
    end
  end

  operation(:show,
    summary: "Retrieve Contact",
    parameters: Schemas.Contact.id_parameters(),
    responses: [
      ok: {"Contact response", "application/json", Schemas.Contact.Response}
    ]
  )

  plug :fetch_contact when action == :show

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, _opts) do
    contact = conn.assigns.contact
    render(conn, "contact.json", %{contact: contact})
  end

  operation(:update,
    summary: "Update Contact",
    parameters: Schemas.Contact.id_parameters(),
    request_body: {"Contact params", "application/json", Schemas.Contact.UpdateParams},
    responses: [
      ok: {"Contact response", "application/json", Schemas.Contact.Response}
    ]
  )

  plug :fetch_contact when action == :update

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, _opts) do
    contact = conn.assigns.contact

    case Contacts.update_contact(contact.id, conn.body_params.data, update_status: true) do
      {:ok, contact} -> render(conn, "contact.json", %{contact: contact})
      {:error, changeset} -> Errors.send_changeset_error(conn, changeset)
    end
  end

  operation(:update_data,
    summary: "Update Contact data",
    description:
      "Update just the `data` field of a Contact. The existing JSON object is merged in a shallow merge with the provided data object.",
    parameters: Schemas.Contact.id_parameters(),
    request_body: {"Contact data params", "application/json", Schemas.Contact.DataParams},
    responses: [
      ok: {"Contact response", "application/json", Schemas.Contact.Response}
    ]
  )

  plug :fetch_contact when action == :update_data

  @spec update_data(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update_data(conn, _opts) do
    contact = conn.assigns.contact
    params = %{data: Map.merge(contact.data || %{}, conn.body_params.data)}

    case Contacts.update_contact(contact.id, params) do
      {:ok, contact} -> render(conn, "contact.json", %{contact: contact})
      {:error, changeset} -> Errors.send_changeset_error(conn, changeset)
    end
  end

  operation(:replace_data,
    summary: "Replace Contact data",
    description: "Replace just the `data` field of a Contact with the provided data object.",
    parameters: Schemas.Contact.id_parameters(),
    request_body: {"Contact data params", "application/json", Schemas.Contact.DataParams},
    responses: [
      ok: {"Contact response", "application/json", Schemas.Contact.Response}
    ]
  )

  plug :fetch_contact when action == :replace_data

  @spec replace_data(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def replace_data(conn, _opts) do
    contact = conn.assigns.contact
    params = %{data: conn.body_params.data}

    case Contacts.update_contact(contact.id, params) do
      {:ok, contact} -> render(conn, "contact.json", %{contact: contact})
      {:error, changeset} -> Errors.send_changeset_error(conn, changeset)
    end
  end

  operation(:delete,
    summary: "Delete Contact",
    parameters: Schemas.Contact.id_parameters(),
    responses: %{
      204 => "Contact was deleted successfully or didn’t exist."
    }
  )

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, %{id: id}) do
    Contacts.delete_project_contacts(project_id(conn), filter: %{"id" => id})

    conn
    |> send_resp(:no_content, "")
  end

  defp project_id(conn), do: conn.assigns.current_project.id

  defp fetch_contact(conn, _opts) do
    project_id = project_id(conn)
    id = conn.params[:id]
    id_type = conn.params[:id_type] || :id

    contact =
      case id_type do
        :id -> Contacts.get_project_contact(project_id, id)
        :email -> Contacts.get_project_contact_by_email(project_id, id)
        :external_id -> Contacts.get_project_contact_by_external_id(project_id, id)
      end

    case contact do
      contact = %Contacts.Contact{} -> assign(conn, :contact, contact)
      nil -> conn |> Errors.send_404() |> halt()
    end
  end
end
