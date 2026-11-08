defmodule Runeshare.Sharing.RedditWatchdogAlarms do
  @moduledoc """
  Watchdog alarms shared in r/runescape's "Watchdog alerts" thread, saved once in
  `priv/imports/reddit_watchdog_alarms.json` and mirrored into the import user's
  shares by `PresetSync` at every boot (so a fresh or existing prod gets them, and
  editing the file updates them). Each credits its Reddit poster and links to the
  comment.
  """

  alias Runeshare.Sharing.PresetSync

  @change_note "Updated from r/runescape"

  @doc "Syncs at boot if an import user is configured; a no-op otherwise."
  @spec sync_on_boot() :: :ok
  def sync_on_boot do
    case PresetSync.author_email() do
      nil -> :ok
      email -> sync_as(email)
    end
  end

  @doc "Syncs the saved alarms as the user with `email`."
  @spec sync_as(String.t()) :: :ok
  def sync_as(email) do
    PresetSync.sync_as(email, %{
      name: "Reddit Watchdog alarms",
      kind: :watchdog_alarm,
      change_note: @change_note,
      fetch: fn -> {:ok, entries()} end
    })
  end

  @doc "The saved alarms as presets."
  @spec entries() :: list(PresetSync.entry())
  def entries do
    :runeshare
    |> Application.app_dir("priv/imports/reddit_watchdog_alarms.json")
    |> File.read!()
    |> JSON.decode!()
    |> Map.fetch!("alarms")
    |> Enum.map(&entry/1)
  end

  defp entry(alarm) do
    credit = "u/" <> alarm["author"]
    credit_line = "Created by #{credit} on r/runescape (#{alarm["url"]})."

    %{
      title: alarm["title"],
      credit: credit,
      description:
        Enum.join(Enum.reject([credit_line, alarm["notes"]], &(&1 in [nil, ""])), "\n\n"),
      content: alarm["content"],
      tags: alarm["tags"]
    }
  end
end
