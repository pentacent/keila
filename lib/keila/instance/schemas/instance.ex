defmodule Keila.Instance.Instance do
  use Keila.Schema

  schema "instance" do
    embeds_many :available_updates, Keila.Instance.Release, on_replace: :delete
  end
end
