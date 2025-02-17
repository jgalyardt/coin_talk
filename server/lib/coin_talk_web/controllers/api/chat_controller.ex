defmodule CoinTalkWeb.Api.ChatController do
  @moduledoc """
  A JSON API for retrieving, creating, and clearing chat messages.
  """
  use CoinTalkWeb, :controller

  alias CoinTalk.Chat
  alias CoinTalk.Repo
  alias CoinTalk.Chat.Message

  @doc """
  Lists recent chat messages.
  """
  def index(conn, _params) do
    messages = Chat.list_messages()
    json(conn, %{messages: messages})
  end

  @doc """
  Creates a new chat message.

  Expects a JSON payload with at least “sender” and “content” keys.
  """
  def create(conn, %{"sender" => _sender, "content" => _content} = params) do
    case Chat.handle_user_message(params) do
      {:ok, message} ->
        json(conn, %{message: message})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: traverse_errors(changeset)})
    end
  end

  @doc """
  Clears the chat and restarts the conversation with new bots.
  """
  def clear(conn, _params) do
    # Delete all chat messages.
    {deleted_count, _} = Repo.delete_all(Message)
    # Generate a new pair of bot names.
    new_bots = generate_new_bot_names()
    # Reset BotResponder with the new bots.
    GenServer.cast(CoinTalk.BotResponder, {:reset, new_bots})
    # Seed a new system prompt to start the conversation.
    {:ok, _} = Chat.create_message(%{
      sender: "system",
      content: "chat cleared. new conversation started with bots #{Enum.join(new_bots, " and ")}. start chatting about bitcoin and usd now."
    })
    json(conn, %{status: "chat cleared", new_bots: new_bots, deleted_count: deleted_count})
  end

  defp traverse_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
  end

  defp generate_new_bot_names do
    # TODO expand bot names
    ["🤖 Al1c3", "🤖 B0b"]
  end
end
