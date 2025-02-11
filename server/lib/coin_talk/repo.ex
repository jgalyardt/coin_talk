defmodule CoinTalk.Repo do
  use Ecto.Repo,
    otp_app: :coin_talk,
    adapter: Ecto.Adapters.Postgres
end
