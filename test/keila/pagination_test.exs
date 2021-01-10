defmodule Keila.PaginationTest do
  use ExUnit.Case, async: true
  import Keila.Factory

  alias Keila.{Pagination, Auth.User, Repo}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  @tag :paginate
  test "paginate queries" do
    insert_n!(:user, 100, fn n -> %{email: "#{n}@example.com"} end)

    assert page = %Pagination{} = Pagination.paginate(User, page_size: 10)
    assert page.page_count == 10
    assert page.page == 0
    assert "1@example.com" in Enum.map(page.data, & &1.email)
    assert "10@example.com" in Enum.map(page.data, & &1.email)
    refute "11@example.com" in Enum.map(page.data, & &1.email)
  end
end
