defmodule Runeshare.Sharing.DiscordWatchdogAlarms do
  @moduledoc """
  Watchdog alarms posted in the Watchdog Discord's alarm channel, mirrored into
  the import user's shares by `PresetSync` (new alarms shared, changed ones edited).

  Discord has no fixed structure for sharing an alarm, so reading the channel is
  split into two lists of strategies:

  - **Finders** (`Finder`): where an export sits in a message. All run, results
    merged: `CodeBlocks`, `InlineJson` (pasted anywhere in the text),
    `TextAttachments` (`.json`/`.txt`, including Discord's `message.txt`).
  - **Layouts** (`Layout`): how messages become presets. Each message goes to the
    first layout that handles it: `ForumPosts` (one preset per forum post), then
    `ChannelMessages` (one per export).

  Each preset credits its Discord creator and links back to the post or message.
  When someone shares the same alarm again, the newest wins.

  Off unless the bot token, the channel id (`config :runeshare, :watchdog_discord,
  channel_id: ...`) and an import user are all configured.
  """

  alias Runeshare.Discord
  alias Runeshare.Sharing
  alias Runeshare.Sharing.PresetSync

  alias Runeshare.Sharing.DiscordWatchdogAlarms.{
    ChannelMessages,
    CodeBlocks,
    ForumPosts,
    InlineJson,
    TextAttachments
  }

  @change_note "Synced from the Watchdog Discord"
  @finders [CodeBlocks, InlineJson, TextAttachments]
  @layouts [ForumPosts, ChannelMessages]

  @doc "Syncs at boot when the bot, the channel and an import user are configured."
  @spec sync_on_boot() :: :ok
  def sync_on_boot do
    email = PresetSync.author_email()

    if email && channel_id() && Discord.configured?(), do: sync_as(email), else: :ok
  end

  @doc "Reads the channel and syncs as the user with `email`."
  @spec sync_as(String.t()) :: :ok
  def sync_as(email) do
    PresetSync.sync_as(email, %{
      name: "Watchdog Discord alarms",
      kind: :watchdog_alarm,
      change_note: @change_note,
      fetch: fn ->
        case Discord.channel_messages(channel_id()) do
          {:ok, messages} -> {:ok, entries(messages)}
          {:error, reason} -> {:error, reason}
        end
      end
    })
  end

  defp channel_id, do: Application.get_env(:runeshare, :watchdog_discord, [])[:channel_id]

  @doc "The presets in `messages` (oldest first, as `Discord.channel_messages/1` returns them)."
  @spec entries(list(Discord.message())) :: list(PresetSync.entry())
  def entries(messages) do
    claimed =
      Enum.group_by(messages, fn message -> Enum.find(@layouts, & &1.handles?(message)) end)

    @layouts
    |> Enum.flat_map(& &1.entries(Map.get(claimed, &1, []), fn message -> exports(message) end))
    |> Enum.reverse()
    |> Enum.uniq_by(&{&1.credit, &1.title})
    |> Enum.reverse()
  end

  # The valid exports in `message`, whichever finders saw them.
  defp exports(message) do
    @finders
    |> Enum.flat_map(& &1.exports(message))
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&(Sharing.check_import_string(:watchdog_alarm, &1) == :ok))
    |> Enum.uniq()
  end
end
