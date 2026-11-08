defmodule Runeshare.Sharing.RedditWatchdogAlarmsTest do
  use Runeshare.DataCase, async: true

  import ExUnit.CaptureLog

  alias Runeshare.Sharing
  alias Runeshare.Sharing.RedditWatchdogAlarms

  test "every saved alarm is a valid Watchdog export" do
    for entry <- RedditWatchdogAlarms.entries() do
      assert Sharing.check_import_string(:watchdog_alarm, entry.content) == :ok, entry.title
    end
  end

  test "shares the saved alarms once, credited to their Reddit posters" do
    author = register_user!(email: "reddit-import@example.com")

    capture_log(fn -> RedditWatchdogAlarms.sync_as("reddit-import@example.com") end)

    presets =
      author.id |> Sharing.list_presets_by_author!(actor: author) |> Map.new(&{&1.title, &1})

    assert map_size(presets) == 6
    assert Map.has_key?(presets, "Inventory nearly full (25 spaces used)")
    assert Map.has_key?(presets, "Inventory nearly full (25 spaces used) – with sound and popup")

    smithing = presets["Smithing Heat"]
    assert smithing.kind == :watchdog_alarm
    assert smithing.tags == ["reddit", "smithing"]

    assert smithing.description =~
             ~r{\ACreated by u/BobotheClown555 on r/runescape \(https://www\.reddit\.com/r/runescape/comments/1xom5j6/comment/\w+/\)\.\n\nI made this one for monitoring smithing heat\.}

    assert capture_log(fn -> RedditWatchdogAlarms.sync_as("reddit-import@example.com") end) =~
             "unchanged: 6"
  end
end
