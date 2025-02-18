defmodule CoinTalk.GeminiClient do
  @moduledoc """
  Client for interacting with Google's Gemini API.
  """

  @api_url "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent"

  def generate_content(prompt) do
    # Simulate network/API variability with a short random delay.
    :timer.sleep(:rand.uniform(500))
    case System.get_env("GEMINI_API_KEY") do
      nil ->
        {:error, "Missing GEMINI_API_KEY environment variable"}

      api_key ->
        body = %{
          "contents" => [%{"parts" => [%{"text" => prompt}]}]
        }

        headers = [{"Content-Type", "application/json"}]

        case Req.post(@api_url <> "?key=" <> api_key, json: body, headers: headers) do
          {:ok,
           %Req.Response{
             status: 200,
             body: %{"candidates" => [%{"content" => %{"parts" => [%{"text" => response}]}}]}
           }} ->
            {:ok, response}

          {:ok, %Req.Response{status: status, body: body}} ->
            {:error, "Request failed: #{status}, #{inspect(body)}"}

          {:error, reason} ->
            {:error, "Request error: #{inspect(reason)}"}
        end
    end
  end
end
