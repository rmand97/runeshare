defmodule Runeshare.Sharing.DiscordWatchdogAlarms do
  @moduledoc """
  Watchdog alarms posted in the Watchdog Discord's alarm channel, mirrored into
  the import user's shares by `PresetSync` (new alarms shared, changed ones edited).

  Reads the channel through the RuneShare bot (`Runeshare.Discord`). An alarm is any
  valid Watchdog export in a message: a code block, the whole message, or a
  `.json`/`.txt` attachment. Each one is credited to the Discord user who posted it,
  with a link back to the message.

  Off unless the bot token, the channel id (`config :runeshare, :watchdog_discord,
  channel_id: ...`) and an import user are all configured.
  """

  alias Runeshare.Discord
  alias Runeshare.Sharing
  alias Runeshare.Sharing.PresetSync

  @change_note "Synced from the Watchdog Discord"
  @max_attachment_bytes 100_000
  @code_block ~r/```[a-z]*\s*(.*?)```/s

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

  @doc """
  The alarms in `messages` (oldest first, as `Discord.channel_messages/1` returns
  them). When a user posts the same alarm again, the newest post wins.
  """
  @spec entries(list(Discord.message())) :: list(PresetSync.entry())
  def entries(messages) do
    messages
    |> Enum.flat_map(&message_entries/1)
    |> Enum.reverse()
    |> Enum.uniq_by(&{&1.credit, &1.title})
    |> Enum.reverse()
  end

  defp message_entries(message) do
    credit = message["author"]["global_name"] || message["author"]["username"] || "someone"

    message
    |> exports()
    |> Enum.map(fn export ->
      %{
        title: title(message, export),
        credit: credit,
        description: description(message, credit),
        content: export,
        tags: ["discord"]
      }
    end)
  end

  defp exports(message) do
    text = message["content"] || ""

    blocks = for [_match, block] <- Regex.scan(@code_block, text), do: block
    whole = if String.starts_with?(String.trim(text), "{"), do: [text], else: []

    files =
      for %{"filename" => name, "url" => url, "size" => size} <- message["attachments"] || [],
          Path.extname(name) in [".json", ".txt"],
          size <= @max_attachment_bytes,
          {:ok, body} <- [Discord.attachment(url)],
          do: body

    (blocks ++ whole ++ files)
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&(Sharing.check_import_string(:watchdog_alarm, &1) == :ok))
    |> Enum.uniq()
  end

  # A forum post's own title, else the export's first alert name.
  defp title(message, export) do
    (message["thread_name"] || Sharing.suggest_title(:watchdog_alarm, export) || "")
    |> String.trim()
    |> String.slice(0, 100)
    |> String.pad_trailing(3, ".")
  end

  defp description(message, credit) do
    link =
      "https://discord.com/channels/#{message["guild_id"]}/#{message["channel_id"]}/#{message["id"]}"

    credit_line = "Created by #{credit} on the Watchdog Discord (#{link})."

    notes =
      (message["content"] || "")
      |> String.replace(@code_block, "")
      |> String.trim()

    if notes == "" or String.starts_with?(notes, "{"),
      do: credit_line,
      else: credit_line <> "\n\n" <> String.slice(notes, 0, 2000 - String.length(credit_line) - 2)
  end
end
