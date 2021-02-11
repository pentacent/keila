defmodule Keila.PaginationTest do
  use Keila.DataCase, async: true
  alias Keila.{Pagination, Auth.User}
  import Ecto.Query
  require Ecto.Query

  @tag :pagination
  test "paginate queries" do
    insert_n!(:user, 101, fn n ->
      %{email: "#{String.pad_leading(to_string(n), 3, "0")}@example.com"}
    end)

    query = from(u in User, order_by: u.email)
    assert page = %Pagination{} = Pagination.paginate(query, page_size: 10)
    assert page.page_count == 11
    assert page.page == 0
    assert "001@example.com" in Enum.map(page.data, & &1.email)
    assert "010@example.com" in Enum.map(page.data, & &1.email)
    refute "011@example.com" in Enum.map(page.data, & &1.email)

    assert page = %Pagination{} = Pagination.paginate(query, page_size: 10, page: 1)
    assert page.page == 1
    assert "011@example.com" in Enum.map(page.data, & &1.email)
  end
end
