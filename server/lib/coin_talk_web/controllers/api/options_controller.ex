defmodule CoinTalkWeb.Api.OptionsController do
  use CoinTalkWeb, :controller

  def options(conn, _params) do
    # Return a 204 No Content response.
    send_resp(conn, 204, "")
  end
end
