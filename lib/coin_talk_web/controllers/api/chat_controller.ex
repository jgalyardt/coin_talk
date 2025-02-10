defmodule CoinTalkWeb.Api.ChatController do
    @moduledoc """
    A JSON API for retrieving and creating chat messages.
    """
    use CoinTalkWeb, :controller
  
    alias CoinTalk.Chat
  
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
  
    defp traverse_errors(changeset) do
      Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
    end
  end
  