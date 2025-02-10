defmodule CoinTalk.GeminiClient do
    @moduledoc "Client for interacting with Google's Gemini API."
  
    @api_url "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent"
    @api_key System.get_env("GEMINI_API_KEY")
  
    def generate_content(prompt) do
      body = %{
        "contents" => [%{"parts" => [%{"text" => prompt}]}]
      }
  
      headers = [{"Content-Type", "application/json"}]
  
      case Req.post(@api_url <> "?key=" <> @api_key, json: body, headers: headers) do
        {:ok, %Req.Response{status: 200, body: %{"candidates" => [%{"content" => %{"parts" => [%{"text" => response}]}}]}}} ->
          {:ok, response}
  
        {:ok, %Req.Response{status: status, body: body}} ->
          {:error, "Request failed: #{status}, #{inspect(body)}"}
  
        {:error, reason} ->
          {:error, "Request error: #{inspect(reason)}"}
      end
    end
  end
  