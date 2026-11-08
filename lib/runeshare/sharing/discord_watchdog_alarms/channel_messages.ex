defmodule Runeshare.Sharing.DiscordWatchdogAlarms.ChannelMessages do
  @moduledoc """
  Layout: a plain text channel, one preset per export, titled by its first
  alert's name and linked to its message.
  """

  @behaviour Runeshare.Sharing.DiscordWatchdogAlarms.Layout

  alias Runeshare.Sharing
  alias Runeshare.Sharing.DiscordWatchdogAlarms.Entry

  @impl true
  def handles?(_message), do: true

  @impl true
  def entries(messages, exports), do: Enum.flat_map(messages, &message_entries(&1, exports))

  defp message_entries(message, exports) do
    credit = Entry.credit(message)

    link =
      "https://discord.com/channels/#{message["guild_id"]}/#{message["channel_id"]}/#{message["id"]}"

    message
    |> exports.()
    |> Enum.map(fn export ->
      %{
        title: Entry.title(Sharing.suggest_title(:watchdog_alarm, export)),
        credit: credit,
        description: Entry.description(link, credit, message["content"]),
        content: export,
        tags: ["discord"]
      }
    end)
  end
end
