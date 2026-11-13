defmodule Keila.Repo.IpAddress do
  @moduledoc """
  Ecto `Postgrex.INET` wrapper type for storing `:inet.ip_address` tuples as Postgres `inet` columns.
  """
  use Ecto.Type

  def type, do: :inet

  def cast(ip) when is_tuple(ip) do
    if :inet.is_ip_address(ip), do: {:ok, ip}, else: :error
  end

  def cast(_other), do: :error

  def dump(ip) when is_tuple(ip) do
    if :inet.is_ip_address(ip), do: {:ok, %Postgrex.INET{address: ip}}, else: :error
  end

  def dump(_other), do: :error

  def load(%Postgrex.INET{address: ip}), do: {:ok, ip}

  def load(_other), do: :error
end
