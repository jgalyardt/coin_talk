defmodule CoinTalkWeb.Api.ChartController do
  @moduledoc """
  A JSON API for returning current BTC market data and historical data.
  """
  use CoinTalkWeb, :controller

  def index(conn, _params) do
    # Get the current market data.
    current = CoinTalk.MarketData.get_current_price()

    price =
      if current do
        current["quote"]["USD"]["price"] |> Float.round(2)
      else
        "N/A"
      end

    # Get historical market data (yesterday, 1 week, 1 month, 1 year).
    historical = CoinTalk.MarketData.get_historical_data()

    data = %{
      bitcoin: %{
        price: price,
        historical: historical
      }
    }

    json(conn, data)
  end
end
