defmodule CoinTalkWeb.Api.ChartController do
  @moduledoc """
  A JSON API for returning (simulated) chart data.
  """
  use CoinTalkWeb, :controller

  @doc """
  Returns current market data for Bitcoin and USD.
  """
  def index(conn, _params) do
    market_context = CoinTalk.MarketData.get_context()
    # Extract the price from the market_context string or
    # update MarketData to expose raw data (e.g., market_data.price)
    # and then construct your JSON response accordingly.
    json(conn, %{market_data: market_context})
  end
end
