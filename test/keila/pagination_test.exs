defmodule Keila.PaginationTest do
  use Keila.DataCase
  alias Keila.{Pagination, Auth.User}

  @tag :pagination
  test "paginate queries" do
    insert_n!(:user, 101, fn n -> %{email: "#{n}@example.com"} end)

    assert page = %Pagination{} = Pagination.paginate(User, page_size: 10)
    assert page.page_count == 11
    assert page.page == 0
    assert "1@example.com" in Enum.map(page.data, & &1.email)
    assert "10@example.com" in Enum.map(page.data, & &1.email)
    refute "11@example.com" in Enum.map(page.data, & &1.email)

    assert page = %Pagination{} = Pagination.paginate(User, page_size: 10, page: 1)
    assert page.page == 1
    assert "11@example.com" in Enum.map(page.data, & &1.email)
  end
end
