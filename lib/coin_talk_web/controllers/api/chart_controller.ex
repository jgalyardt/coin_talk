defmodule CoinTalkWeb.Api.ChartController do
    @moduledoc """
    A JSON API for returning (simulated) chart data.
    """
    use CoinTalkWeb, :controller
  
    @doc """
    Returns current market data for Bitcoin and USD.
  
    (For demo purposes the prices are randomized.)
    """
    def index(conn, _params) do
      data = %{
        bitcoin: %{price: random_price(30000, 60000)},
        usd: %{exchange_rate: random_price(0.8, 1.2)}
      }
  
      json(conn, data)
    end
  
    defp random_price(min, max) do
      (:rand.uniform() * (max - min) + min)
      |> Float.round(2)
    end
  end
  