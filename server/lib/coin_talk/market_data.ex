defmodule CoinTalk.MarketData do
  @moduledoc """
  Fetches BTC market data from the CoinMarketCap API at a rate that respects
  the free plan limit (roughly one update every 4–5 minutes).

  Maintains a record of the latest current price and historical data.
  Historical data includes: price 1 day ago, 1 week ago, 1 month ago, and 1 year ago.

  If the historical endpoint is not supported, dummy fallback values are used:
    - Yesterday (2025-02-14): $97,499.63
    - 1 Week Ago (2025-02-08): $96,650.00
    - 1 Month Ago (2025-01-15): $100,700.00
    - 1 Year Ago (2024-02-15): $51,800.00
  """

  use GenServer

  @poll_interval 300_000
  defstruct current: nil, historical: nil, last_updated: nil

  # Public API

  def start_link(_args) do
    GenServer.start_link(__MODULE__, %__MODULE__{}, name: __MODULE__)
  end

  @doc "Returns the latest current BTC price data."
  def get_current_price do
    GenServer.call(__MODULE__, :get_current)
  end

  @doc "Returns the historical BTC data as a map with keys :yesterday, :week, :month, and :year."
  def get_historical_data do
    GenServer.call(__MODULE__, :get_historical)
  end

  @doc """
  Returns a formatted context string that includes the current BTC price
  and historical data. (Intended for use in bot prompts.)
  """
  def get_context do
    GenServer.call(__MODULE__, :get_context)
  end

  # GenServer callbacks

  def init(state) do
    # Trigger an immediate poll so data is available right away.
    schedule_poll(0)
    {:ok, state}
  end

  def handle_info(:poll, state) do
    with {:ok, current_data} <- fetch_current_market_data(),
         {:ok, historical_data} <- fetch_all_historical_data() do
      timestamp = System.system_time(:millisecond)

      new_state = %{
        state
        | current: current_data,
          historical: historical_data,
          last_updated: timestamp
      }

      # Rapid movement alerts
      if state.current && new_state.current do
        old_price = state.current["quote"]["USD"]["price"]
        new_price = new_state.current["quote"]["USD"]["price"]
        change = (new_price - old_price) / old_price * 100.0

        if abs(change) >= 1.0 do
          alert_msg = "market alert: bitcoin price changed by #{Float.round(change, 2)}%!"
          _ = CoinTalk.Chat.create_message(%{sender: "system", content: alert_msg})
        end
      end

      schedule_poll()
      {:noreply, new_state}
    else
      error ->
        IO.puts("MarketData fetch error: #{inspect(error)}")
        schedule_poll()
        {:noreply, state}
    end
  end

  def handle_call(:get_current, _from, state) do
    {:reply, state.current, state}
  end

  def handle_call(:get_historical, _from, state) do
    {:reply, state.historical, state}
  end

  def handle_call(:get_context, _from, state) do
    current_price =
      if state.current do
        state.current["quote"]["USD"]["price"] |> Float.round(2)
      else
        "N/A"
      end

    historical = state.historical || %{}

    context = """
    Current Price: $#{current_price}
    Historical Data:
      Yesterday: $#{historical.yesterday || "N/A"}
      1 Week Ago: $#{historical.week || "N/A"}
      1 Month Ago: $#{historical.month || "N/A"}
      1 Year Ago: $#{historical.year || "N/A"}
    """

    {:reply, context, state}
  end

  # Helper functions

  defp schedule_poll(delay \\ @poll_interval) do
    Process.send_after(self(), :poll, delay)
  end

  # Fetch the current BTC market data using the "quotes/latest" endpoint.
  defp fetch_current_market_data do
    api_key = Application.fetch_env!(:coin_talk, CoinTalk.MarketData)[:coinmarketcap_api_key]
    url = "https://pro-api.coinmarketcap.com/v1/cryptocurrency/quotes/latest"
    params = [symbol: "BTC", convert: "USD"]

    headers = [
      {"X-CMC_PRO_API_KEY", api_key},
      {"Accept", "application/json"}
    ]

    case Req.get(url, params: params, headers: headers) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        btc_data = body["data"]["BTC"]
        {:ok, btc_data}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, "Current request failed: #{status} - #{inspect(body)}"}

      {:error, reason} ->
        {:error, "HTTP error: #{inspect(reason)}"}
    end
  end

  # Fetch historical data for key dates, using fallback dummy values if needed.
  defp fetch_all_historical_data do
    today = Date.utc_today()

    dates = %{
      yesterday: Date.add(today, -1),
      week: Date.add(today, -7),
      month: Date.add(today, -30),
      year: Date.add(today, -365)
    }

    with {:ok, price_yesterday} <- fetch_historical_data_or_dummy(dates.yesterday, 97_499.63),
         {:ok, price_week} <- fetch_historical_data_or_dummy(dates.week, 96_650.00),
         {:ok, price_month} <- fetch_historical_data_or_dummy(dates.month, 100_700.00),
         {:ok, price_year} <- fetch_historical_data_or_dummy(dates.year, 51_800.00) do
      {:ok, %{yesterday: price_yesterday, week: price_week, month: price_month, year: price_year}}
    else
      _ ->
        # In case of any unexpected error, return the dummy data.
        {:ok, %{yesterday: 97_499.63, week: 96_650.00, month: 100_700.00, year: 51_800.00}}
    end
  end

  # Attempt to fetch the historical price for a given date, falling back to dummy data on error.
  defp fetch_historical_data_or_dummy(date, fallback) do
    case fetch_historical_price(date) do
      {:ok, price} ->
        {:ok, price}

      {:error, reason} ->
        IO.puts(
          "Historical data error for #{Date.to_iso8601(date)}: #{inspect(reason)}. Using fallback value."
        )

        {:ok, fallback}
    end
  end

  # Given a Date, fetch BTC’s historical quote for that day using the quotes/historical endpoint.
  defp fetch_historical_price(date) do
    iso_date = Date.to_iso8601(date)
    api_key = Application.fetch_env!(:coin_talk, CoinTalk.MarketData)[:coinmarketcap_api_key]
    url = "https://pro-api.coinmarketcap.com/v1/cryptocurrency/quotes/historical"
    params = [symbol: "BTC", date: iso_date, convert: "USD"]

    headers = [
      {"X-CMC_PRO_API_KEY", api_key},
      {"Accept", "application/json"}
    ]

    case Req.get(url, params: params, headers: headers) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        quotes = get_in(body, ["data", "BTC", "quotes"])

        case quotes do
          [first | _] ->
            price = first["quote"]["USD"]["price"] |> Float.round(2)
            {:ok, price}

          _ ->
            {:error, "No quotes found for #{iso_date}"}
        end

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, "Historical request failed: #{status} - #{inspect(body)}"}

      {:error, reason} ->
        {:error, "HTTP error: #{inspect(reason)}"}
    end
  end
end
