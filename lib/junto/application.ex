defmodule Junto.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      JuntoWeb.Telemetry,
      Junto.Repo,
      {DNSCluster, query: Application.get_env(:junto, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Junto.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Junto.Finch},
      # Start a worker by calling: Junto.Worker.start_link(arg)
      # {Junto.Worker, arg},
      # Start to serve requests, typically the last entry
      JuntoWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Junto.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    JuntoWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
