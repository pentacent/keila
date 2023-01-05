defmodule KeilaWeb.ApiSenderView do
  use KeilaWeb, :view
  alias Keila.Pagination

  def render("senders.json", %{senders: senders = %Pagination{}}) do
    %{
      "meta" => %{
        "page" => senders.page,
        "page_count" => senders.page_count,
        "count" => senders.count
      },
      "data" => Enum.map(senders.data, &sender_data/1)
    }
  end

  @properties [:id, :name, :from_email, :from_name, :reply_to_email, :reply_to_name]
  defp sender_data(sender) do
    sender
    |> Map.take(@properties)
  end
end
