defmodule Keila.Mailings do
  use Keila.Repo
  alias Keila.Project
  alias Keila.Mailings.Sender

  @moduledoc """
  Context for all functionalities related to sending email campaigns.
  """

  @spec get_sender(Sender.id()) :: Sender.t() | nil
  def get_sender(id) when is_binary(id) or is_integer(id),
    do: Repo.get(Sender, id)

  def get_sender(_),
    do: nil

  @spec get_project_sender(Project.id(), Sender.id()) :: Sender.t() | nil
  def get_project_sender(project_id, sender_id) do
    case get_sender(sender_id) do
      sender = %Sender{project_id: ^project_id} -> sender
      _other -> nil
    end
  end

  @spec get_project_senders(Project.id()) :: [Project.t()]
  def get_project_senders(project_id) when is_binary(project_id) or is_integer(project_id) do
    from(s in Sender, where: s.project_id == ^project_id)
    |> Repo.all()
  end

  @spec create_sender(Project.id(), map()) ::
          {:ok, Sender.t()} | {:error, Changeset.t(Sender.t())}
  def create_sender(project_id, params) do
    params
    |> stringize_params()
    |> Map.put("project_id", project_id)
    |> Sender.creation_changeset()
    |> Repo.insert()
  end

  @spec update_sender(Sender.id(), map()) :: {:ok, Sender.t()} | {:error, Changeset.t(Sender.t())}
  def update_sender(id, params) when is_binary(id) or is_integer(id) do
    Repo.get(Sender, id)
    |> Sender.update_changeset(params)
    |> Repo.update()
  end

  @doc """
  Deletes Sender with given ID. Associated Campaigns are *not* deleted.

  This function is idempotent and always returns `:ok`.
  """
  @spec delete_sender(Sender.id()) :: :ok
  def delete_sender(id) when is_binary(id) or is_integer(id) do
    from(s in Sender, where: s.id == ^id)
    |> Repo.delete_all()
  end
end
