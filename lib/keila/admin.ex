defmodule Keila.Admin do
  @moduledoc """
  Context for manual admin and maintenance tasks.

  TODO It’s worth considering evolving this module into one for managing
  account-related data that should not necessarily be part of the Auth context.
  """

  use Keila.Repo
  alias Keila.Auth
  alias Keila.Auth.{User, Group, UserGroup}

  @doc """
  Deletes a user from the database including all data from projects which belong
  to this user only.
  """
  @spec purge_user(User.id()) :: :ok
  def purge_user(id) do
    user = Repo.get(User, id)

    user_groups = Auth.list_user_groups(user.id)
    user_group_ids = Enum.map(user_groups, & &1.id)
    root_group = Auth.root_group()

    :ok = Auth.delete_user(id)

    empty_user_groups =
      from(ug in UserGroup,
        where: ug.group_id in ^user_group_ids,
        distinct: ug.group_id,
        select: ug.group_id
      )

    from(g in Group,
      where:
        g.id in ^user_group_ids and g.id != ^root_group.id and
          g.id not in subquery(empty_user_groups)
    )
    |> Repo.delete_all()

    :ok
  end
end
