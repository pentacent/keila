defmodule Keila.TestSenderAdapter do
  use Keila.Mailings.SenderAdapters.Adapter

  @impl true
  def name, do: "test"

  @impl true
  def schema_fields,
    do: [test_string: :string, test_verification_callback_success_at: :utc_datetime]

  @impl true
  def changeset(changeset, params) do
    cast(changeset, params, [:test_string])
  end

  @impl true
  def to_swoosh_config(_struct), do: []

  @impl true
  def after_create(sender) do
    if sender.config.test_string == "callback-fail" do
      {:error, "after_create callback failed"}
    else
      :ok
    end
  end

  @impl true
  def after_update(sender) do
    if sender.config.test_string == "callback-fail" do
      {:error, "after_update callback failed"}
    else
      :ok
    end
  end

  @impl true
  def before_delete(sender) do
    if sender.config.test_string == "callback-fail" do
      {:error, "before_delete callback failed"}
    else
      :ok
    end
  end

  @impl true
  def after_from_email_verification(sender) do
    if sender.config.test_string == "callback-fail" do
      {:error, "verify_from_token callback failed"}
    else
      sender
      |> change(%{
        config:
          change(sender.config, %{test_verification_callback_success_at: DateTime.utc_now()})
      })
      |> Keila.Repo.update!()
      |> then(fn sender -> {:ok, sender} end)
    end
  end

  @impl true
  def requires_verification?(), do: true
end
