defmodule CoinTalkWeb.BotChatController do
  use CoinTalkWeb, :controller

  alias CoinTalk.Chat

  def index(conn, _params) do
    messages = Chat.list_messages(50)

    IO.puts("\n=== Bot Chat Conversation ===")

    Enum.each(messages, fn msg ->
      IO.puts("[#{msg.inserted_at}] #{msg.sender}: #{msg.content}")
    end)

    IO.puts("=== End of Conversation ===\n")

    send_resp(conn, 200, "Bot conversation has been logged to the console.\n")
  end
end
