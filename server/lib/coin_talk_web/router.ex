defmodule CoinTalkWeb.Router do
  use CoinTalkWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {CoinTalkWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug CORSPlug, origin: ["http://localhost:5173"]
    plug :accepts, ["json"]
    plug CoinTalkWeb.Plugs.RateLimiter
  end

  scope "/", CoinTalkWeb do
    pipe_through :browser

    get "/", DefaultController, :index

    # New route for viewing the bot conversation
    get "/botchat", BotChatController, :index
  end

  # API endpoints for chart data and chat messages.
  scope "/api", CoinTalkWeb.Api, as: :api do
    pipe_through :api

    get "/charts", ChartController, :index
    resources "/chat", ChatController, only: [:index, :create]
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:coin_talk, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: CoinTalkWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
