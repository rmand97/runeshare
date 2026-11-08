defmodule Runeshare.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias Runeshare.Repo.SlowQueryLog
  alias Runeshare.Sharing.Imports

  @impl true
  def start(_type, _args) do
    SlowQueryLog.attach()

    children = [
      RuneshareWeb.Telemetry,
      Runeshare.Repo,
      {DNSCluster, query: Application.get_env(:runeshare, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Runeshare.PubSub},
      # Start a worker by calling: Runeshare.Worker.start_link(arg)
      # {Runeshare.Worker, arg},
      # Start to serve requests, typically the last entry
      RuneshareWeb.Endpoint,
      {AshAuthentication.Supervisor, [otp_app: :runeshare]},
      # Pull new and changed presets from the wiki, Reddit and the Watchdog Discord
      # once per boot (prod; each is off until configured).
      {Task, &Imports.sync_on_boot/0}
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Runeshare.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    RuneshareWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
