defmodule KeilaWeb.ApiView do
  use KeilaWeb, :view
  alias Keila.Pagination

  def render("contacts.json", %{contacts: contacts = %Pagination{}}) do
    %{
      "meta" => %{
        "page" => contacts.page,
        "pageCount" => contacts.page_count,
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

  def render("not_authorized.json", _assigns) do
    %{
      "errors" => [
        %{"status" => "403", "title" => "Not authorized"}
      ]
    }
  end

  def render("errors.json", errors) do
    %{
      "errors" => Enum.map(errors, &inspect/1)
    }

    # TODO properly transform errors
  end

  defp contact_data(contact) do
    %{
      "id" => contact.id,
      "firstName" => contact.first_name,
      "lastName" => contact.last_name,
      "email" => contact.email,
      "insertedAt" => contact.inserted_at,
      "updatedAt" => contact.updated_at,
      "data" => contact.data
    }
  end
end
