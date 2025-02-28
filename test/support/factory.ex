defmodule Keila.Factory do
  @moduledoc """
  The idea behind this simple Factory module comes straight from the
  [Ecto documentation](https://hexdocs.pm/ecto/test-factories.html)

  You must call Keila.Factory.start_counter/0 in `text_helpers.exs` to
  enable the build counter.
  """
  alias Keila.Repo

  defp do_build(:user) do
    %Keila.Auth.User{
      email: "foo-#{get_counter_value()}@bar.com",
      password_hash: Argon2.hash_pwd_salt("BatteryHorseStaple")
    }
  end

  defp do_build(:activated_user) do
    do_build(:user)
    |> Map.put(:activated_at, DateTime.utc_now() |> DateTime.truncate(:second))
  end

  defp do_build(:group) do
    %Keila.Auth.Group{
      name: "group-#{get_counter_value()}"
    }
  end

  defp do_build(:role) do
    %Keila.Auth.Role{}
  end

  defp do_build(:user_group) do
    %Keila.Auth.UserGroup{}
  end

  defp do_build(:user_group_role) do
    %Keila.Auth.UserGroupRole{}
  end

  defp do_build(:permission) do
    %Keila.Auth.Permission{
      name: "permission-#{get_counter_value()}"
    }
  end

  defp do_build(:role_permission) do
    %Keila.Auth.RolePermission{}
  end

  defp do_build(:project) do
    %Keila.Projects.Project{
      name: "project-#{get_counter_value()}"
    }
  end

  defp do_build(:mailings_sender) do
    %Keila.Mailings.Sender{
      name: "sender-#{get_counter_value()}",
      from_email: "sender-#{get_counter_value()}@example.com",
      config: %{
        type: "smtp",
        smtp_relay: "mail.example.com",
        smtp_username: "foo",
        smtp_password: "BatteryHorseStaple"
      }
    }
  end

  defp do_build(:mailings_shared_sender) do
    %Keila.Mailings.SharedSender{
      name: "shared-sender-#{get_counter_value()}",
      config: %{
        type: "ses",
        ses_region: "eu-west-1",
        ses_access_key: "foo",
        ses_secret: "bar"
      }
    }
  end

  defp do_build(:mailings_campaign) do
    %Keila.Mailings.Campaign{
      subject: "subject-#{get_counter_value()}",
      text_body: "body-#{get_counter_value()}",
      settings: %{
        type: :text
      }
    }
  end

  defp do_build(:mailings_recipient) do
    %Keila.Mailings.Recipient{}
  end

  defp do_build(:template) do
    %Keila.Templates.Template{
      name: "template-#{get_counter_value()}"
    }
  end

  defp do_build(:contact) do
    %Keila.Contacts.Contact{
      email: "contact-#{get_counter_value()}@example.org",
      first_name: "First-#{get_counter_value()}",
      last_name: "Last-#{get_counter_value()}",
      external_id: Ecto.UUID.generate()
    }
  end

  defp do_build(:contacts_form) do
    %Keila.Contacts.Form{
      name: "form-#{get_counter_value()}@example.org",
      settings: %{},
      field_settings: [%{field: :email, cast: true, required: true}]
    }
  end

  defp do_build(:contacts_form_params) do
    %Keila.Contacts.FormParams{}
  end

  defp do_build(:contacts_segment) do
    %Keila.Contacts.Segment{
      name: "segment-#{get_counter_value()}@example.org",
      filter: %{}
    }
  end

  defp do_build(:account) do
    %Keila.Accounts.Account{
      group: build(:group)
    }
  end

  defp do_build(:file) do
    %Keila.Files.File{
      uuid: Ecto.UUID.generate(),
      filename: "test/keila/files/keila.jpg",
      type: "image/jpeg",
      size: 1234,
      adapter: "local",
      project_id: build(:project).id
    }
  end

  @doc """
  Builds a struct with optional attributes
  """
  def build(name, attributes \\ []) do
    increment_counter()
    name |> do_build() |> struct(attributes)
  end

  def build_n(name, n, attribute_fn \\ fn _n -> [] end) do
    for i <- 1..n do
      build(name, attribute_fn.(i))
    end
  end

  @doc """
  Build and persists a struct with optional attributes
  """
  def insert!(name, attributes \\ []) do
    name |> build(attributes) |> Repo.insert!()
  end

  def insert_n!(name, n, attribute_fn \\ fn _n -> [] end) do
    for i <- 1..n do
      insert!(name, attribute_fn.(i))
    end
  end

  @doc """
  Builds params for a struct with optional attributes
  """
  def params(name, attributes \\ [])

  def params(:user, attributes) do
    build(:user, attributes)
    |> maybe_to_map()
    |> Map.put("password", "BatteryHorseStaple")
  end

  def params(name, attributes) do
    build(name, attributes)
    |> maybe_to_map()
  end

  defp maybe_to_map(struct) when is_struct(struct) do
    struct
    |> Map.from_struct()
    |> Enum.map(fn {key, value} -> {to_string(key), maybe_to_map(value)} end)
    |> Enum.filter(fn {key, _} -> not String.starts_with?(key, "__") end)
    |> Enum.into(%{})
  end

  defp maybe_to_map(other), do: other

  def start_counter,
    do: Agent.start_link(fn -> :rand.uniform(10_000) end, name: Keila.Factory.Counter)

  defp increment_counter,
    do: Agent.update(Keila.Factory.Counter, &(&1 + 1))

  defp get_counter_value,
    do: Agent.get(Keila.Factory.Counter, & &1)
end
