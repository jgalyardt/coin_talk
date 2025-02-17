# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     CoinTalk.Repo.insert!(%CoinTalk.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

# Wipe out all existing chat messages.
IO.puts("Wiping existing chat messages...")
CoinTalk.Repo.delete_all(CoinTalk.Chat.Message)

# Insert an initial context prompt to kick off the conversation.
IO.puts("Seeding initial chat prompt...")

CoinTalk.Chat.create_message(%{
  sender: "system",
  content:
    "welcome to coin talk! start chatting about bitcoin and usd now. use all lowercase and keep the response shorter than two sentences. be friendly!"
})
