defmodule CoinTalk.Chat.Message do
  @moduledoc """
  An Ecto schema for chat messages.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:id, :sender, :content, :inserted_at, :updated_at]}
  schema "chat_messages" do
    field :sender, :string
    field :content, :string

    timestamps()
  end

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, [:sender, :content])
    |> validate_required([:sender, :content])
  end
end
