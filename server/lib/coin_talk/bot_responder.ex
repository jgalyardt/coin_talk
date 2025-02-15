defmodule CoinTalk.BotResponder do
  @moduledoc """
  Every 5 seconds, if no user message has been received recently,
  triggers a chatbot response that incorporates the latest market data and
  the past 10 minutes of chat history. The response is styled as irreverent,
  internet chat room shitposting.
  """
  use GenServer
  require Logger

  # 5 seconds in milliseconds
  @idle_interval 5000
  @bots ["Al1c3", "B0b"]

  # Public API

  def start_link(_args) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  # GenServer callbacks

  def init(state) do
    schedule_idle_check()
    {:ok, state}
  end

  def handle_info(:idle_check, state) do
    last_user_msg = CoinTalk.Chat.UserMessageTracker.get_last_message_timestamp()
    now = System.system_time(:millisecond)

    if now - last_user_msg >= @idle_interval do
      trigger_bot_response()
    end

    schedule_idle_check()
    {:noreply, state}
  end

  defp schedule_idle_check do
    Process.send_after(self(), :idle_check, @idle_interval)
  end

  defp trigger_bot_response do
    # Get the market data context summary.
    market_context = CoinTalk.MarketData.get_context()

    # Get chat history for the past 2 minutes.
    chat_history = CoinTalk.Chat.list_recent_chats(2)
    chat_history_str = format_chat_history(chat_history)

    # Extract the most recent message to serve as the conversational anchor.
    last_message =
      case List.last(chat_history) do
        nil ->
          "no previous message"

        %_{inserted_at: inserted_at, sender: sender, content: content} ->
          "[#{NaiveDateTime.to_string(inserted_at)}] #{sender}: #{content}"
      end

    # Construct a prompt that instructs the chatbot to respond directly to the last message.
    prompt = """
    You are a chatbot in an internet chat room.
    Be friendly, and think about the trends in the data before commenting.
    Your response should directly address the most recent statement in the conversation: "#{last_message}"
    Your reply should be humorous and reflect the current market mood
    Responses must be one sentence max all lowercase with no punctuation
    Chat history of last 2 minutes:
    #{chat_history_str}
    Market Data Context:
    #{market_context}
    """

    # Choose one of the bot names at random.
    bot = Enum.random(@bots)

    # Call the Gemini API to generate content.
    case CoinTalk.GeminiClient.generate_content(prompt) do
      {:ok, response} ->
        # Insert the bot response as a chat message and log it at the info level.
        case CoinTalk.Chat.create_message(%{sender: bot, content: response}) do
          {:ok, message} ->
            Logger.info(
              "[#{NaiveDateTime.to_string(message.inserted_at)}] #{message.sender}: #{message.content}"
            )

          {:error, error} ->
            Logger.error("Failed to create bot message: #{inspect(error)}")
        end

      {:error, reason} ->
        Logger.error("BotResponder error: #{reason}")
    end
  end

  defp format_chat_history(chat_messages) do
    chat_messages
    |> Enum.map(fn msg ->
      # Keep the full context of each message for the prompt.
      time = NaiveDateTime.to_string(msg.inserted_at)
      "[#{time}] #{msg.sender}: #{msg.content}"
    end)
    |> Enum.join("\n")
  end
end
