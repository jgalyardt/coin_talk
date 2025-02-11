defmodule CoinTalk.MarketData do
    @moduledoc """
    Fetches BTC market data from the CoinMarketCap API at a rate that respects
    the free plan limit (roughly 0.23 updates/minute, i.e. one update every 4–5 minutes).
    Maintains a record of the latest data and some dummy historical snapshots.
    """
    use GenServer
  
    # Set to 5 minutes (300_000 ms) to be safe.
    @poll_interval 300_000
  
    defstruct data: nil, historical: nil, last_updated: nil
  
    # Public API
  
    def start_link(_args) do
      GenServer.start_link(__MODULE__, %__MODULE__{}, name: __MODULE__)
    end
  
    @doc "Returns a formatted string of the current BTC market data for inclusion in chatbot prompts."
    def get_context do
      GenServer.call(__MODULE__, :get_context)
    end
  
    # GenServer callbacks
  
    def init(state) do
      # Initialize with dummy historical data (e.g. 5pm EST snapshots for the past 3 days)
      historical = generate_historical_data()
      state = %{state | historical: historical}
      # Trigger an immediate poll on startup
      schedule_poll(0)
      {:ok, state}
    end
  
    def handle_info(:poll, state) do
      case fetch_market_data() do
        {:ok, btc_data} ->
          timestamp = System.system_time(:millisecond)
          new_state = %{state | data: btc_data, last_updated: timestamp}
          schedule_poll()
          {:noreply, new_state}
  
        {:error, reason} ->
          IO.puts("MarketData fetch error: #{reason}")
          schedule_poll()
          {:noreply, state}
      end
    end
  
    def handle_call(:get_context, _from, state) do
      context = format_context(state)
      {:reply, context, state}
    end
  
    # Helper functions
  
    defp schedule_poll(delay \\ @poll_interval) do
      Process.send_after(self(), :poll, delay)
    end
  
    defp fetch_market_data do
      api_key = System.get_env("COINMARKETCAP_API_KEY")
  
      if api_key == nil do
        {:error, "Missing COINMARKETCAP_API_KEY environment variable"}
      else
        url = "https://pro-api.coinmarketcap.com/v1/cryptocurrency/quotes/latest"
        params = [symbol: "BTC", convert: "USD"]
        headers = [
          {"X-CMC_PRO_API_KEY", api_key},
          {"Accept", "application/json"}
        ]
  
        case Req.get(url, params: params, headers: headers) do
          {:ok, %Req.Response{status: 200, body: body}} ->
            # Assuming the BTC data is found at body["data"]["BTC"]
            btc_data = body["data"]["BTC"]
            {:ok, btc_data}
  
          {:ok, %Req.Response{status: status, body: body}} ->
            {:error, "Request failed: #{status} - #{inspect(body)}"}
  
          {:error, reason} ->
            {:error, "HTTP error: #{inspect(reason)}"}
        end
      end
    end
  
    defp format_context(state) do
      market_info =
        if state.data do
          price = state.data["quote"]["USD"]["price"] |> Float.round(2)
          percent_change_24h = state.data["quote"]["USD"]["percent_change_24h"] |> Float.round(2)
          "BTC Price: $#{price} (24h change: #{percent_change_24h}%)"
        else
          "No data available"
        end
  
      last_updated =
        if state.last_updated do
          state.last_updated
          |> DateTime.from_unix!(:millisecond)
          |> DateTime.to_naive()
          |> NaiveDateTime.to_string()
        else
          "Never"
        end
  
      """
      Current Market Data (last updated: #{last_updated}):
      #{market_info}
  
      Historical Data (5pm EST snapshots):
      #{state.historical}
      """
    end
  
    defp generate_historical_data do
      # Generate dummy snapshots for the past 3 days.
      today = Date.utc_today()
  
      1..3
      |> Enum.map(fn days_ago ->
        date = Date.add(today, -days_ago)
        price = random_price(30000, 60000)
        "Date #{date} 5pm EST - BTC: $#{price}"
      end)
      |> Enum.join("\n")
    end
  
    defp random_price(min, max) do
      (:rand.uniform() * (max - min) + min)
      |> Float.round(2)
    end
  end
  