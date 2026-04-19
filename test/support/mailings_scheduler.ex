defmodule Keila.MailingsSchedulerTestHelper do
  alias Keila.Mailings.Scheduler

  def schedule_messages() do
    {:ok, scheduler} = Scheduler.start_link(name: nil)
    Ecto.Adapters.SQL.Sandbox.allow(Keila.Repo, self(), scheduler)

    Scheduler.schedule(scheduler)
  end
end
