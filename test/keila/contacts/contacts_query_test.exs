defmodule Keila.ContactsQueryTest do
  use ExUnit.Case, async: true
  import Keila.Factory

  alias Keila.{Contacts, Projects, Repo}
  alias Contacts.{Contact, Query}
  require Ecto.Query
  import Ecto.Query

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    _root = insert!(:group)
    user = insert!(:user)
    {:ok, project} = Projects.create_project(user.id, params(:project))

    %{project: project}
  end

  @tag :contacts_query
  test "sort contact query" do
    c1 = insert!(:contact, %{email: "a@example.com", first_name: nil})
    c2 = insert!(:contact, %{email: "b@example.com", first_name: "X"})
    c3 = insert!(:contact, %{email: "c@example.com", first_name: "Y"})

    assert [c1, c2, c3] ==
             from(Contact)
             |> Query.apply(sort: %{"email" => 1})
             |> Repo.all()

    assert [c3, c2, c1] ==
             from(Contact)
             |> Query.apply(sort: %{"email" => -1})
             |> Repo.all()

    assert [c1, c3, c2] ==
             from(Contact)
             |> Query.apply(sort: %{"first_name" => -1})
             |> Repo.all()
  end

  @tag :contacts_query
  defp insert_filter_test_contacts!() do
    c1 =
      insert!(:contact, %{
        email: "a@example.com",
        first_name: "A",
        inserted_at: ~N[2020-01-01 10:01:00Z]
      })

    c2 =
      insert!(:contact, %{
        email: "b@example.com",
        first_name: "B",
        inserted_at: ~N[2020-01-01 10:02:00Z]
      })

    c3 =
      insert!(:contact, %{
        email: "c@example.com",
        first_name: "C",
        inserted_at: ~N[2020-02-01 10:01:00Z]
      })

    c4 =
      insert!(:contact, %{
        email: "d@example.com",
        first_name: "D",
        inserted_at: ~N[2020-02-01 10:02:00Z]
      })

    [c1, c2, c3, c4]
  end

  @tag :contacts_query
  test "filter by string equality" do
    [c1, _c2, _c3, _c4] = insert_filter_test_contacts!()

    assert [c1] ==
             from(Contact)
             |> Query.apply(filter: %{"email" => "a@example.com"})
             |> Repo.all()
  end

  @tag :contacts_query
  test "filter by string $in" do
    [c1, c2, _c3, _c4] = insert_filter_test_contacts!()

    assert [c1, c2] ==
             from(Contact)
             |> Query.apply(filter: %{"email" => %{"$in" => ["a@example.com", "b@example.com"]}})
             |> Repo.all()
  end

  @tag :contacts_query
  test "filter by date comparison" do
    [_c1, _c2, c3, c4] = insert_filter_test_contacts!()

    assert [c3, c4] ==
             from(Contact)
             |> Query.apply(filter: %{"inserted_at" => %{"$gt" => "2020-01-01 10:02:00Z"}})
             |> Repo.all()
  end

  @tag :contacts_query
  test "filter using $or" do
    [_c1, _c2, c3, c4] = insert_filter_test_contacts!()

    filter = %{
      "$or" => [
        %{"email" => "c@example.com"},
        %{"inserted_at" => %{"$gt" => "2020-02-01 10:01:00Z"}}
      ]
    }

    assert [c3, c4] ==
             from(Contact)
             |> Query.apply(filter: filter)
             |> Repo.all()
  end

  @tag :contacts_query
  test "filter using $not" do
    [c1, c2, _c3, c4] = insert_filter_test_contacts!()

    filter = %{
      "$not" => %{"email" => "c@example.com"}
    }

    assert [c1, c2, c4] ==
             from(Contact)
             |> Query.apply(filter: filter)
             |> Repo.all()
  end

  @tag :contacts_query
  test "filter for nil values. String 'null' is not treated as nil." do
    c = insert!(:contact, %{first_name: nil})

    assert [c] ==
             from(Contact)
             |> Query.apply(filter: %{"first_name" => nil})
             |> Repo.all()

    assert [] ==
             from(Contact)
             |> Query.apply(filter: %{"first_name" => "null"})
             |> Repo.all()
  end
end
