defmodule CoinTalk.BotResponder do
  @moduledoc """
  Triggers chatbot responses with dynamic behavior:

  - **Passive mode (no humans):**  
    Each bot speaks at most once per hour and bots alternate turns.

  - **Active mode (human connected):**  
    Bots reply roughly every 20–30 seconds even to each other.

  - **Immediate human reply:**  
    When a human sends a message, all bots immediately respond.

  Bots never reply to a message that they themselves sent.
  """
  use GenServer
  require Logger

  # Intervals in milliseconds
  @passive_interval 3_600_000     # 1 hour per bot in passive mode
  @active_interval 25_000         # roughly every 25 seconds in active mode
  @check_interval 5_000           # default periodic check

  # Public API

  def start_link(_args) do
    # Initialize state with a bots list (now stored in state)
    state = %{
      bots: ["🤖 Al1c3", "🤖 B0b"],
      last_bot: nil,
      bot_timestamps: %{"🤖 Al1c3" => 0, "🤖 B0b" => 0},
      mode: :passive,
      last_human_message_ts: 0
    }
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
    new_state = %{state | mode: :active, last_human_message_ts: System.system_time(:millisecond)}
    Enum.each(state.bots, fn bot ->
      generate_bot_response(bot, human_msg, context_minutes: 2, force: true)
    end)
    {:noreply, new_state}
  end

  # Handle a cast to reset the conversation with new bots.
  @impl true
  def handle_cast({:reset, new_bots}, state) do
    Logger.info("Resetting bot responder with new bots: #{inspect(new_bots)}")
    new_bot_timestamps = Enum.reduce(new_bots, %{}, fn bot, acc -> Map.put(acc, bot, 0) end)
    {:noreply, %{state | bots: new_bots, bot_timestamps: new_bot_timestamps, last_bot: nil}}
  end

  # Periodic check to decide if a bot should respond.
  @impl true
  def handle_info(:check, state) do
    now = System.system_time(:millisecond)
    # If a human message was received within the last 5 seconds, skip periodic responses.
    if now - state.last_human_message_ts < 5_000 do
      Logger.debug("Recent human message detected, skipping periodic bot response")
      schedule_check(@check_interval)
      {:noreply, state}
    else
      mode = determine_mode()
      state = %{state | mode: mode}
      last_chat = CoinTalk.Chat.get_last_message()

      cond do
        # In passive mode, let bots alternate by not replying if a bot was the last speaker.
        mode == :passive and last_chat && last_chat.sender in state.bots ->
          Logger.debug("Passive mode: last message by #{last_chat.sender}; waiting for a new speaker.")
          :noop

        mode == :active ->
          bot = choose_next_bot(state.last_bot, state.bot_timestamps, @active_interval, state.bots)
          state = maybe_respond(bot, last_chat, state, context_minutes: 2)
          state

        mode == :passive ->
          bot = choose_next_bot(state.last_bot, state.bot_timestamps, @passive_interval, state.bots)
          state = maybe_respond(bot, last_chat, state, context_minutes: 24)
          state
      end

      schedule_check(@check_interval)
      {:noreply, state}
    end
  end

  # Helper: schedule the next periodic check.
  defp schedule_check(interval) do
    Process.send_after(self(), :check, interval)
  end

  # Helper: choose the next bot (from the given bots list) that did not send the last message and whose cooldown has expired.
  defp choose_next_bot(last_bot, bot_timestamps, interval, bots) do
    now = System.system_time(:millisecond)
    bots
    |> Enum.reject(fn bot -> bot == last_bot end)
    |> Enum.find(fn bot ->
      now - Map.get(bot_timestamps, bot, 0) >= interval
    end)
  end

  # Helper: if a bot is eligible, generate a response and update state.
  defp maybe_respond(nil, _last_chat, state, _opts) do
    Logger.debug("No eligible bot found for response at this time.")
    # Remove any stale "is typing..." messages.
    CoinTalk.Chat.clear_stale_typing_messages()
    state
  end


  defp maybe_respond(bot, last_chat, state, opts) do
    now = System.system_time(:millisecond)

    if last_chat && last_chat.sender == bot do
      Logger.debug("#{bot} was the last to speak. Skipping its response.")
      state
    else
      generate_bot_response(bot, last_chat, opts)
      new_timestamps = Map.put(state.bot_timestamps, bot, now)
      %{state | bot_timestamps: new_timestamps, last_bot: bot}
    end
  end

  # Determine the current mode.
  defp determine_mode do
    last_user_ts = CoinTalk.Chat.UserMessageTracker.get_last_message_timestamp()
    now = System.system_time(:millisecond)
    if now - last_user_ts < 60_000, do: :active, else: :passive
  end

  # Generate a bot response.
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

    # Use a randomized prompt to vary tone and content.
    prompt = randomized_prompt(bot, anchor, chat_history_str, context_minutes, market_context)

    # Spawn a Task so the GenServer remains responsive.
    Task.start(fn ->
      # Stagger initial response to avoid simultaneous typing.
      initial_delay = :rand.uniform(1000)
      :timer.sleep(initial_delay)
      # Create a temporary typing message.
      case CoinTalk.Chat.create_message(%{sender: bot, content: "#{bot} is typing..."}) do
        {:ok, _typing_message} ->
          # Simulate typing delay.
          delay = :rand.uniform(2000) + 1000
          :timer.sleep(delay)
          case CoinTalk.GeminiClient.generate_content(prompt) do
            {:ok, response} ->
              # Instead of updating the typing message, create a new message.
              case CoinTalk.Chat.create_message(%{sender: bot, content: response}) do
                {:ok, message} ->
                  Logger.info("[#{NaiveDateTime.to_string(message.inserted_at)}] #{bot}: #{response}")
                {:error, error} ->
                  Logger.error("Failed to create bot response: #{inspect(error)}")
              end
            {:error, reason} ->
              Logger.error("Gemini error: #{reason}")
              _ = CoinTalk.Chat.create_message(%{sender: bot, content: "error: #{reason}"})
          end
        {:error, error} ->
          Logger.error("Failed to create typing message for #{bot}: #{inspect(error)}")
      end
    end)
  end

  # Returns a randomized prompt to vary tone and content.
  defp randomized_prompt(_bot, anchor, chat_history_str, context_minutes, market_context) do
    prompts = [
      # Friendly and concise
      "you are a friendly chatbot in a busy market chat. comment on bitcoin and usd using the last message \"#{anchor}\" with chat history (last #{context_minutes} minutes):\n#{chat_history_str}\nmarket update:\n#{market_context}\nrespond in one short sentence in lowercase without punctuation",
      # Witty and succinct
      "act as a witty market analyst. with humor and brevity, comment on the message \"#{anchor}\" and the following conversation:\n#{chat_history_str}\nmarket details:\n#{market_context}\nrespond in one sentence all lowercase no punctuation",
      # Sarcastic tone
      "you are a sarcastic crypto commentator. review the recent chat \"#{anchor}\" with context:\n#{chat_history_str}\nmarket info:\n#{market_context}\nanswer in a brief sarcastic remark in lowercase without punctuation",
      # Optimistic crypto enthusiast
      "imagine you are an upbeat crypto enthusiast discussing bitcoin and usd. using the last message \"#{anchor}\", the chat history:\n#{chat_history_str}\nand market update:\n#{market_context}\ngive a short, optimistic comment in one sentence all lowercase without punctuation",
      # Down-to-earth trader
      "you are a seasoned trader with a no-nonsense style. analyze the message \"#{anchor}\" and recent chat:\n#{chat_history_str}\nmarket context:\n#{market_context}\nrespond in one brief, factual sentence in lowercase without punctuation",
      # Casual banter style
      "you're just chatting about the market with your pals. comment on \"#{anchor}\" using the chat history (last #{context_minutes} minutes):\n#{chat_history_str}\nand current market details:\n#{market_context}\nreply in one casual sentence all lowercase without punctuation",
      # Analytical perspective
      "assume the role of an analytical market bot. consider the message \"#{anchor}\", the conversation:\n#{chat_history_str}\nand market update:\n#{market_context}\nprovide a concise analytical remark in one sentence in lowercase without punctuation"
    ]
    Enum.random(prompts)
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
