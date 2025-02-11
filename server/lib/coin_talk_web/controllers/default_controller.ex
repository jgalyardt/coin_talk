# lib/coin_talk_web/controllers/default_controller.ex
defmodule CoinTalkWeb.DefaultController do
  use CoinTalkWeb, :controller

  def index(conn, _params) do
    json(conn, %{
      message: "Welcome to Coin Talk",
      version: "1.0"
    })
  end
end
