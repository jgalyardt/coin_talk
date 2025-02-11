defmodule CoinTalk.Repo.Migrations.CreateChatMessages do
  use Ecto.Migration

  def change do
    create table(:chat_messages) do
      add :sender, :string, null: false
      add :content, :text, null: false

      timestamps()
    end
  end
end
