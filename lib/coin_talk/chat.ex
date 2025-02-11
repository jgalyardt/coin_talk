defmodule CoinTalk.Chat do
  @moduledoc """
  The Chat context for storing messages and (now) triggering bot responses via a periodic process.
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
  Handles a user–submitted message. If the sender is not a bot,
  the last user message timestamp is updated.
  """
  def handle_user_message(attrs) do
    case create_message(attrs) do
      {:ok, message} ->
        if message.sender not in ["Al1c3", "B0b"] do
          # Update the last user message timestamp (in milliseconds)
          CoinTalk.Chat.UserMessageTracker.set_last_message_timestamp(
            System.system_time(:millisecond)
          )
        end

        # (Removed immediate bot triggering in favor of periodic BotResponder.)
        {:ok, message}

      error ->
        error
    end
  end

  @doc """
  Lists chat messages from the past `minutes` minutes.
  """
  def list_recent_chats(minutes) do
    cutoff = NaiveDateTime.add(NaiveDateTime.utc_now(), -minutes * 60, :second)
    query = from m in Message, where: m.inserted_at >= ^cutoff, order_by: [asc: m.inserted_at]
    Repo.all(query)
  end
end
