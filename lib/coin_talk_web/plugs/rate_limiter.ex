defmodule CoinTalkWeb.Plugs.RateLimiter do
  @moduledoc """
  A simple ETS–based rate limiter plug.

  For each incoming API request the plug will inspect the caller’s IP address
  (as determined from `conn.remote_ip`) and allow at most @limit requests per @interval.
  If the rate is exceeded a 429 status is returned.
  """

  import Plug.Conn

  # maximum requests allowed per interval
  @limit 60
  # interval in milliseconds (60 seconds)
  @interval 60_000

  def init(opts), do: opts

  def call(conn, _opts) do
    ensure_table_exists()
    ip = ip_to_string(conn.remote_ip)
    now = System.system_time(:millisecond)

    case check_rate(ip, now) do
      :ok ->
        conn

      :error ->
        conn
        |> send_resp(429, "Rate limit exceeded")
        |> halt()
    end
  end

  defp ip_to_string(remote_ip) when is_tuple(remote_ip) do
    remote_ip
    |> Tuple.to_list()
    |> Enum.join(".")
  end

  defp ensure_table_exists do
    table = :rate_limiter_table

    # Create the table if it does not already exist.
    if :ets.whereis(table) == :undefined do
      :ets.new(table, [:named_table, :public, read_concurrency: true])
    end

    :ok
  end

  defp check_rate(ip, now) do
    table = :rate_limiter_table

    case :ets.lookup(table, ip) do
      [] ->
        :ets.insert(table, {ip, 1, now})
        :ok

      [{^ip, count, timestamp}] ->
        if now - timestamp < @interval do
          if count < @limit do
            :ets.insert(table, {ip, count + 1, timestamp})
            :ok
          else
            :error
          end
        else
          # Reset the counter if the interval has passed.
          :ets.insert(table, {ip, 1, now})
          :ok
        end
    end
  end
end
