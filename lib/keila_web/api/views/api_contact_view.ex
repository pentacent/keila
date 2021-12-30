defmodule KeilaWeb.ApiContactView do
  use KeilaWeb, :view
  alias Keila.Pagination

  def render("contacts.json", %{contacts: contacts = %Pagination{}}) do
    %{
      "meta" => %{
        "page" => contacts.page,
        "page_count" => contacts.page_count,
        "count" => contacts.count
      },
      "data" => Enum.map(contacts.data, &contact_data/1)
    }
  end

  def render("contact.json", %{contact: contact}) do
    %{
      "data" => contact_data(contact)
    }
  end

  @properties [:id, :first_name, :last_name, :email, :data, :updated_at, :inserted_at]
  defp contact_data(contact) do
    contact
    |> Map.take(@properties)
  end
end
