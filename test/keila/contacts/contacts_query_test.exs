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
        inserted_at: ~U[2020-01-01 10:01:00Z]
      })

    c2 =
      insert!(:contact, %{
        email: "b@example.com",
        first_name: "B",
        inserted_at: ~U[2020-01-01 10:02:00Z]
      })

    c3 =
      insert!(:contact, %{
        email: "c@example.com",
        first_name: "C",
        inserted_at: ~U[2020-02-01 10:01:00Z]
      })

    c4 =
      insert!(:contact, %{
        email: "d@example.com",
        first_name: "D",
        inserted_at: ~U[2020-02-01 10:02:00Z]
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

  @tag :contacts_query
  test "filter using $empty operator" do
    c1 = insert!(:contact, %{first_name: nil})
    c2 = insert!(:contact, %{first_name: ""})
    c3 = insert!(:contact, %{first_name: "Jane", double_opt_in_at: DateTime.utc_now(:second)})

    assert [^c1, ^c2] = filter_contacts(%{"first_name" => %{"$empty" => true}})
    assert [^c3] = filter_contacts(%{"first_name" => %{"$empty" => false}})
    assert [^c1, ^c2] = filter_contacts(%{"double_opt_in_at" => %{"$empty" => true}})
  end

  @tag :contacts_query
  test "filter for custom data" do
    c1 =
      insert!(:contact, %{
        data: %{
          "string" => "foo",
          "array" => [1, 2, 3],
          "object" => %{"a" => "b"},
          "objects" => [%{"b" => "c"}]
        }
      })

    c2 =
      insert!(:contact, %{
        data: %{
          "string" => "bar",
          "stringOnly2" => "yes",
          "array" => [4, 5, 6],
          "object" => %{"d" => %{"e" => "f"}},
          "objects" => [%{"e" => "f"}]
        }
      })

    # Query strings
    assert [c1] == filter_contacts(%{"data.string" => "foo"})
    assert [c2] == filter_contacts(%{"data.string" => "bar"})

    # Query arrays
    assert [c1] == filter_contacts(%{"data.array" => 1})
    assert [c1] == filter_contacts(%{"data.array" => 2})

    # Query object matches in arrays
    assert [c1] == filter_contacts(%{"data.objects" => %{"b" => "c"}})
    assert [c1] == filter_contacts(%{"data.objects.0.b" => "c"})

    # Query nested objects
    assert [c2] == filter_contacts(%{"data.object" => %{"d" => %{"e" => "f"}}})
    assert [c2] == filter_contacts(%{"data.object.d" => %{"e" => "f"}})
    assert [c2] == filter_contacts(%{"data.object.d.e" => "f"})

    # Query with operators
    assert [c1] == filter_contacts(%{"data.string" => %{"$in" => ["foobar", "foo"]}})
    assert [c2] == filter_contacts(%{"data.string" => %{"$in" => ["foobar", "bar"]}})
    assert [] == filter_contacts(%{"data.array.2" => %{"$lt" => 3}})
    assert [c1] == filter_contacts(%{"data.array.2" => %{"$lte" => 3}})
    assert [] == filter_contacts(%{"data.array.0" => %{"$gt" => 4}})
    assert [c2] == filter_contacts(%{"data.array.0" => %{"$gte" => 4}})

    # Like operator
    assert [c1] == filter_contacts(%{"data.string" => %{"$like" => "%o%"}})
    assert [c2] == filter_contacts(%{"data.string" => %{"$like" => "%A%"}})

    # Not operator
    assert [c1, c2] == filter_contacts(%{"$not" => %{"data.string" => "no_match"}})
    assert [c1, c2] == filter_contacts(%{"$not" => %{"data.stringOnly2" => "no_match"}})
    assert [c1] == filter_contacts(%{"$not" => %{"data.stringOnly2" => "yes"}})
  end

  @tag :contacts_query
  test "support $empty operator for custom data" do
    c1 =
      insert!(:contact, %{
        data: %{
          "empty_string_field" => "",
          "non_empty_field" => "foo",
          "empty_list_field" => [],
          "non_empty_list_field" => ["foo"],
          "empty_object_field" => %{},
          "non_empty_object_field" => %{"foo" => "bar"}
        }
      })

    c2 = insert!(:contact)

    assert [c1, c2] == filter_contacts(%{"data.empty_string_field" => %{"$empty" => true}})
    assert [c1] == filter_contacts(%{"data.non_empty_field" => %{"$empty" => false}})
    assert [c2] == filter_contacts(%{"data.non_empty_field" => %{"$empty" => true}})

    assert [c1, c2] == filter_contacts(%{"data.empty_list_field" => %{"$empty" => true}})
    assert [c1] == filter_contacts(%{"data.non_empty_list_field" => %{"$empty" => false}})
    assert [c2] == filter_contacts(%{"data.non_empty_list_field" => %{"$empty" => true}})

    assert [c1, c2] == filter_contacts(%{"data.empty_object_field" => %{"$empty" => true}})
    assert [c1] == filter_contacts(%{"data.non_empty_object_field" => %{"$empty" => false}})
    assert [c2] == filter_contacts(%{"data.non_empty_object_field" => %{"$empty" => true}})
  end

  @tag :contacts_query
  test "safely validate query opts" do
    assert true == Query.valid_opts?(filter: %{"email" => "foo@example.com"})
    assert false == Query.valid_opts?(filter: %{"invalid_field" => "foo@example.com"})
  end

  defp filter_contacts(filter) do
    from(Contact) |> Query.apply(filter: filter) |> Repo.all()
  end
end
