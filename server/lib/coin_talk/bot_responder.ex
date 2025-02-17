defmodule CoinTalk.BotResponder do
  @moduledoc """
  Triggers chatbot responses with dynamic behavior:

  - **Passive mode (no humans):**  
    Each bot speaks at most once per hour and bots alternate turns.

  - **Active mode (human connected but no new human message):**  
    Bots reply roughly every 20–30 seconds.

  - **Immediate human reply:**  
    When a human sends a message, all bots immediately respond.

  Bots never reply to a message that they themselves sent.
  """
  use GenServer
  require Logger

  @bots ["🤖 Al1c3", "🤖 B0b"]

  # Intervals in milliseconds
  # 1 hour per bot in passive mode
  @passive_interval 3_600_000
  # roughly every 25 seconds in active mode
  @active_interval 25_000
  # default periodic check
  @check_interval 5_000

  # Public API

  def start_link(_args) do
    # Initial state:
    # - last_bot: the name of the bot that last sent a message (or nil)
    # - bot_timestamps: map tracking when each bot last responded
    # - mode: either :passive or :active
    state = %{last_bot: nil, bot_timestamps: %{"Al1c3" => 0, "B0b" => 0}, mode: :passive}
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  @impl true
  def init(state) do
    schedule_check(@check_interval)
    {:ok, state}
  end

  # Handle a cast triggered by a human message.
  @impl true
  def handle_cast({:human_message, human_msg}, state) do
    Logger.info("Received human message, triggering immediate bot responses.")

    Enum.each(@bots, fn bot ->
      generate_bot_response(bot, human_msg, context_minutes: 2, force: true)
    end)

    {:noreply, %{state | mode: :active}}
  end

  # Periodic check to decide if a bot should respond
  @impl true
  def handle_info(:check, state) do
    # Determine current mode. (For example, you could check Phoenix Presence here.)
    mode = determine_mode()
    state = %{state | mode: mode}

    # Get the most recent message; if none, returns nil.
    last_chat = CoinTalk.Chat.get_last_message()

    cond do
      # If the most recent message was from a bot, don’t have that same bot reply immediately.
      last_chat && last_chat.sender in @bots ->
        Logger.debug("Last message by #{last_chat.sender}; waiting for a new speaker.")
        :noop

      mode == :active ->
        # In active mode, if the last message is not from a bot (or is nil),
        # let the bot that did not speak last reply if its active cooldown has passed.
        bot = choose_next_bot(state.last_bot, state.bot_timestamps, @active_interval)
        state = maybe_respond(bot, last_chat, state, context_minutes: 2)
        state

      mode == :passive ->
        # In passive mode, have bots reply at most once per hour, alternating speakers,
        # and use a larger context window (last 24 hours)
        bot = choose_next_bot(state.last_bot, state.bot_timestamps, @passive_interval)
        state = maybe_respond(bot, last_chat, state, context_minutes: 24)
        state
    end

    schedule_check(@check_interval)
    {:noreply, state}
  end

  # Helper: schedule the next periodic check
  defp schedule_check(interval) do
    Process.send_after(self(), :check, interval)
  end

  # Helper: choose the next bot that did not send the last message and whose cooldown has expired.
  defp choose_next_bot(last_bot, bot_timestamps, interval) do
    now = System.system_time(:millisecond)

    @bots
    |> Enum.reject(fn bot -> bot == last_bot end)
    |> Enum.find(fn bot ->
      now - Map.get(bot_timestamps, bot, 0) >= interval
    end)
  end

  # Helper: if a bot is eligible, generate a response and update state.
  defp maybe_respond(nil, _last_chat, state, _opts) do
    Logger.debug("No eligible bot found for response at this time.")
    state
  end

  defp maybe_respond(bot, last_chat, state, opts) do
    now = System.system_time(:millisecond)

    # Safety check: if the last message was from this bot, skip.
    if last_chat && last_chat.sender == bot do
      Logger.debug("#{bot} was the last to speak. Skipping its response.")
      state
    else
      generate_bot_response(bot, last_chat, opts)
      # Update bot’s cooldown timestamp and record it as the last bot who spoke.
      new_timestamps = Map.put(state.bot_timestamps, bot, now)
      %{state | bot_timestamps: new_timestamps, last_bot: bot}
    end
  end

  # Determine the current mode.
  # (For demonstration, we use the timestamp of the last human message.
  # In a real app, you might track connected users via Phoenix.Presence.)
  defp determine_mode do
    last_user_ts = CoinTalk.Chat.UserMessageTracker.get_last_message_timestamp()
    now = System.system_time(:millisecond)
    # If a human message was received in the last minute, assume active.
    if now - last_user_ts < 60_000, do: :active, else: :passive
  end

  # Helper: Generate a bot response.
  # - `opts` expects a keyword list with:
  #   - `:context_minutes` – how many minutes of chat history to include.
  #   - `:force` – when true, ignore cooldown checks (used for immediate human replies).
defp generate_bot_response(bot, last_chat, opts) do
  market_context = CoinTalk.MarketData.get_context()
  context_minutes = Keyword.get(opts, :context_minutes, 2)
  chat_history = CoinTalk.Chat.list_recent_chats(context_minutes)
  chat_history_str = format_chat_history(chat_history)

  anchor =
    case last_chat do
      nil ->
        "no previous message"
      %_{inserted_at: inserted_at, sender: sender, content: content} ->
        "[#{NaiveDateTime.to_string(inserted_at)}] #{sender}: #{content}"
    end

  prompt = """
  you are a chatbot in an internet chat room
  be friendly and humorous while commenting on market trends
  address the most recent message: "#{anchor}"
  chat history (last #{context_minutes} minutes):
  #{chat_history_str}
  market context:
  #{market_context}
  responses must be one sentence max all lowercase with no punctuation
  """

  # Spawn a task per bot response.
  Task.start(fn ->
    # Random delay before showing typing indicator (to stagger if multiple bots are triggered)
    initial_delay = :rand.uniform(1000)
    :timer.sleep(initial_delay)

    # Insert the typing indicator.
    case CoinTalk.Chat.create_message(%{sender: bot, content: "#{bot} is typing..."}) do
      {:ok, typing_message} ->
        # Random delay (1 to 3 seconds) to simulate "typing..."
        delay = :rand.uniform(2000) + 1000
        :timer.sleep(delay)

        # Now, fetch the actual bot response from Gemini.
        case CoinTalk.GeminiClient.generate_content(prompt) do
          {:ok, response} ->
            # Update the "typing" message with the final response.
            case CoinTalk.Chat.update_message(typing_message, %{content: response}) do
              {:ok, message} ->
                Logger.info("[#{NaiveDateTime.to_string(message.inserted_at)}] #{bot}: #{response}")
              {:error, error} ->
                Logger.error("Failed to update bot message: #{inspect(error)}")
            end

          {:error, reason} ->
            Logger.error("Gemini error: #{reason}")
            _ = CoinTalk.Chat.update_message(typing_message, %{content: "error: #{reason}"})
        end

      {:error, error} ->
        Logger.error("Failed to create typing message for #{bot}: #{inspect(error)}")
    end
  end)
end


  defp format_chat_history(chat_messages) do
    chat_messages
    |> Enum.map(fn msg ->
      time = NaiveDateTime.to_string(msg.inserted_at)
      "[#{time}] #{msg.sender}: #{msg.content}"
    end)
    |> Enum.join("\n")
  end
end
