defmodule Keila.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      Keila.Repo,
      # Start the Telemetry supervisor
      KeilaWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Keila.PubSub},
      # Start the Endpoint (http/https)
      KeilaWeb.Endpoint,
      # Start Oban
      {Oban, oban_config()}
      # Start a worker by calling: Keila.Worker.start_link(arg)
      # {Keila.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Keila.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    KeilaWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp oban_config() do
    Application.get_env(:keila, Oban)
  end
end
