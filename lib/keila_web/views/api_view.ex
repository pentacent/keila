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

  def render("errors.json", %{errors: errors}) do
    %{
      "errors" => Enum.map(errors, &error_object/1)
    }
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

  defp error_object(error) do
    status = error |> Keyword.fetch!(:status) |> to_string()
    {title, detail} = error_object(error[:title], error[:detail])

    %{"status" => status, "title" => title, "detail" => detail}
  end

  defp error_object(title, detail = %Jason.DecodeError{}) do
    title = title || "Invalid JSON"
    detail = Jason.DecodeError.message(detail)
    {title, detail}
  end
end
