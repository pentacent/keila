defmodule Keila.Mailings.SenderAdapters.Postmark do
  use Keila.Mailings.SenderAdapters.Adapter

  @impl true
  def name, do: "postmark"

  @impl true
  def schema_fields do
    [
      postmark_api_key: :string,
      postmark_message_stream: :string
    ]
  end

  @impl true
  def changeset(changeset, params) do
    changeset
    |> cast(params, [:postmark_api_key, :postmark_message_stream])
    |> validate_required([:postmark_api_key])
  end

  @impl true
  def to_swoosh_config(%{config: config}) do
    [
      adapter: Swoosh.Adapters.Postmark,
      api_key: config.postmark_api_key
    ]
  end

  @impl true
  def put_provider_options(email, %{config: config}) do
    case config.postmark_message_stream do
      nil ->
        email

      message_stream ->
        Swoosh.Email.put_provider_option(email, :message_stream, message_stream)
    end
  end
end
