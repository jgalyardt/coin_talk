defmodule CoinTalk.Chat do
    @moduledoc """
    The Chat context for storing messages and triggering bot responses.
    """
  
    import Ecto.Query, warn: false
    alias CoinTalk.Repo
    alias CoinTalk.Chat.Message
  
    @doc """
    Lists the most recent chat messages (by default the last 50).
    """
    def list_messages(limit \\ 50) do
      Message
      |> order_by([m], desc: m.inserted_at)
      |> limit(^limit)
      |> Repo.all()
      |> Enum.reverse()
    end
  
    @doc """
    Creates a new chat message.
    """
    def create_message(attrs \\ %{}) do
      %Message{}
      |> Message.changeset(attrs)
      |> Repo.insert()
    end
  
    @doc """
    Handles a user–submitted message and, if successful, triggers bot responses.
    """
    def handle_user_message(attrs) do
      case create_message(attrs) do
        {:ok, message} ->
          # Trigger bot responses asynchronously if the sender is not a bot.
          Task.start(fn -> maybe_trigger_bots(message) end)
          {:ok, message}
  
        error ->
          error
      end
    end
  
    defp maybe_trigger_bots(%Message{sender: sender} = message) do
      if sender not in ["Al1c3", "B0b"] do
        # For demonstration, trigger responses from both bots.
        for bot <- ["Al1c3", "B0b"] do
          prompt = "React to the conversation: #{message.content}"
          case CoinTalk.GeminiClient.generate_content(prompt) do
            {:ok, response} ->
              create_message(%{sender: bot, content: response})
            {:error, _reason} ->
              :noop
          end
        end
      end
    end
  end
  