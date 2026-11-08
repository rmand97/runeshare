defmodule Runeshare.Sharing.Imports do
  @moduledoc """
  The outside sources mirrored into the import user's shares at boot, run one after
  the other: RuneScape Wiki tile markers, saved Reddit alarms, Watchdog Discord
  alarms. Each is a no-op until configured (see `PresetSync.author_email/0`).
  """

  alias Runeshare.Sharing.{DiscordWatchdogAlarms, RedditWatchdogAlarms, WikiTileMarkers}

  @sources [WikiTileMarkers, RedditWatchdogAlarms, DiscordWatchdogAlarms]

  @doc "Runs every source's boot sync."
  @spec sync_on_boot() :: :ok
  def sync_on_boot, do: Enum.each(@sources, & &1.sync_on_boot())
end
