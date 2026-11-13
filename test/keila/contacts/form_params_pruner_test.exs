defmodule Keila.Contacts.FormParamsPrunerTest do
  use Keila.DataCase, async: true

  alias Keila.Contacts.FormParams
  alias Keila.Contacts.FormParamsPruner

  setup do
    threshold = FormParams.retention_days()

    group = insert!(:group)
    project = insert!(:project, group: group)
    form = insert!(:contacts_form, project_id: project.id)

    %{threshold: threshold, form: form}
  end

  test "deletes form params older than threshold and preserves recent ones", %{
    threshold: threshold,
    form: form
  } do
    old = insert!(:contacts_form_params, form_id: form.id, inserted_at: days_ago(threshold + 1))

    recent =
      insert!(:contacts_form_params, form_id: form.id, inserted_at: days_ago(threshold - 1))

    FormParamsPruner.perform(%Oban.Job{})

    assert is_nil(Repo.reload(old))
    assert Repo.reload(recent)
  end

  test "deletes form params in batches and re-enqueues itself", %{
    threshold: threshold,
    form: form
  } do
    batch_size = FormParamsPruner.batch_size()

    insert_n!(:contacts_form_params, batch_size + 1, fn _n ->
      [form_id: form.id, inserted_at: days_ago(threshold + 1)]
    end)

    Oban.insert!(FormParamsPruner.new(%{}))

    assert %{success: 1} = Oban.drain_queue(queue: :system)
    assert Repo.aggregate(FormParams, :count) == 1

    assert %{success: 1} = Oban.drain_queue(queue: :system)
    assert Repo.aggregate(FormParams, :count) == 0

    assert %{success: 0} = Oban.drain_queue(queue: :system)
  end

  defp days_ago(n) do
    DateTime.utc_now(:second) |> DateTime.add(-n, :day)
  end
end
