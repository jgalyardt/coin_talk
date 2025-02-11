defmodule CoinTalk.Chat.UserMessageTracker do
  @moduledoc """
  Keeps track of the timestamp (in milliseconds) of the last user–submitted chat message.
  """
  use Agent

  def start_link(_args) do
    # Initialize with 0 (epoch) so that if no message has been sent,
    # the idle check will trigger immediately.
    Agent.start_link(fn -> 0 end, name: __MODULE__)
  end

  @doc "Sets the timestamp (in milliseconds) for the last user message."
  def set_last_message_timestamp(timestamp) do
    Agent.update(__MODULE__, fn _old -> timestamp end)
  end

  @doc "Returns the timestamp (in milliseconds) of the last user message."
  def get_last_message_timestamp do
    Agent.get(__MODULE__, & &1)
  end
end
