defmodule CoinTalk.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      CoinTalkWeb.Telemetry,
      CoinTalk.Repo,
      {DNSCluster, query: Application.get_env(:coin_talk, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: CoinTalk.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: CoinTalk.Finch},
      # Start the tracker for the last user message timestamp
      CoinTalk.Chat.UserMessageTracker,
      # Start the market data monitor (polling every 2 seconds)
      CoinTalk.MarketData,
      # Start the bot responder (checks every 5 seconds)
      CoinTalk.BotResponder,
      # Start to serve requests, typically the last entry
      CoinTalkWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: CoinTalk.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    CoinTalkWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
