require Keila

Keila.if_cloud do
  defmodule KeilaCloud.Workers.SenderDomainVerificationWorker do
    @moduledoc """
    Worker for running `SendWithKeila.verify_domain/1` in the background.
    """

    use Oban.Worker, queue: :domain_verification, max_attempts: 1

    alias Keila.Mailings
    alias Keila.Mailings.Sender

    @impl Oban.Worker
    def perform(%Oban.Job{args: %{"sender_id" => sender_id}}) do
      with sender = %Sender{} <- Mailings.get_sender(sender_id),
           {:ok, _} <- KeilaCloud.Mailings.SendWithKeila.verify_domain(sender) do
        :ok
      else
        nil -> {:cancel, "sender not found"}
        {:error, reason} -> {:cancel, reason}
      end
    end
  end
end
