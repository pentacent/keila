defmodule Keila.Repo.Migrations.Auth do
  use Ecto.Migration

  def change do
    create table("users") do
      add :email, :string, null: false
      add :password_hash, :string
      add :activated_at, :utc_datetime
      timestamps()
    end

    create unique_index("users", [:email])

    create table("tokens") do
      add :scope, :string, null: false
      add :user_id, references("users", on_delete: :delete_all)
      add :key, :binary, length: 32
      add :expires_at, :utc_datetime
      add :data, :map
      timestamps(updated_at: false)
    end

    create table("groups") do
      add :parent_id, references("groups", on_delete: :delete_all)
      add :name, :string
      timestamps()
    end

    create table("roles") do
      add :parent_id, references("roles", on_delete: :delete_all)
      add :name, :string
      timestamps()
    end

    create table("permissions") do
      add :name, :string, unique: true
      timestamps()
    end

    create unique_index("permissions", [:name])

    create table("user_groups") do
      add :user_id, references("users", on_delete: :delete_all), null: false
      add :group_id, references("groups", on_delete: :delete_all), null: false
      timestamps()
    end

    create unique_index("user_groups", [:user_id, :group_id])

    create table("user_group_roles") do
      add :user_group_id, references("user_groups", on_delete: :delete_all), null: false
      add :role_id, references("roles", on_delete: :delete_all), null: false
      timestamps()
    end

    create unique_index("user_group_roles", [:user_group_id, :role_id])

    create table("role_permissions") do
      add :role_id, references("roles", on_delete: :delete_all), null: false
      add :permission_id, references("permissions", on_delete: :delete_all), null: false
      add :is_inherited, :boolean, default: false
      timestamps()
    end

    create unique_index("role_permissions", [:role_id, :permission_id])
  end
end
