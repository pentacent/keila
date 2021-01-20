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

  defp do_build(:contact) do
    %Keila.Contacts.Contact{
      email: "contact-#{get_counter_value()}@example.org",
      first_name: "First-#{get_counter_value()}",
      last_name: "Last-#{get_counter_value()}"
    }
  end

  defp do_build(:contacts_form) do
    %Keila.Contacts.Form{
      name: "form-#{get_counter_value()}@example.org",
      settings: %{},
      field_settings: [%{field: "email", cast: true, required: true}]
    }
  end

  @doc """
  Builds a struct with optional attributes
  """
  def build(name, attributes \\ []) do
    increment_counter()
    name |> do_build() |> struct(attributes)
  end

  def build_n(name, n, attribute_fn \\ fn n -> [] end) do
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

  def insert_n!(name, n, attribute_fn \\ fn n -> [] end) do
    for i <- 1..n do
      insert!(name, attribute_fn.(i))
    end
  end

  @doc """
  Builds params for a struct with optional attributes
  """
  def params(name, attributs \\ []) do
    build(name, attributs)
    |> maybe_to_map()
  end

  defp maybe_to_map(struct) when is_struct(struct) do
    struct
    |> Map.from_struct()
    |> Enum.map(fn {key, value} -> {to_string(key), maybe_to_map(value)} end)
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
