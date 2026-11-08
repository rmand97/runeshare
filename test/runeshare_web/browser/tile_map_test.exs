defmodule RuneshareWeb.Browser.TileMapTest do
  use PhoenixTest.Playwright.Case, async: true

  use RuneshareWeb, :verified_routes

  import Runeshare.Test.Builders
  import RuneshareWeb.BrowserHelpers

  # Real browser; skipped in CI (`mix test --exclude playwright`).
  @moduletag :playwright

  # Real preset from the RuneScape Wiki: 29 tiles on the ground floor, 7 on the
  # 1st floor, two of them labelled "walk nw" and "surge from here".
  @araxxor "TM2IwdhcmF4eG9yHa6G3Ay74aIDAgEBCwEDAQKJBDB3kgUCBgIKAgYCAgMBCwEDAa7f2BUH0q-KGgfNkQEBCwEDAshk__-gUMyMDBTIZP__oFDMjAAUAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAwAAAAAAB3dhbGsgbncPc3VyZ2UgZnJvbSBoZXJl"

  # "Master Clue Tile markers" from the RuneScape Wiki: dig spots all over the world,
  # so no tile is near the median position.
  @spread_out "TM2MwdNYXN0ZXJz9wGjucMG1QJ3wAGEiQH0BpEBtwHQCX7l0QEGGtIE-QMwEqMY2xYTjp6dAeEC2AUMBwEDJwIGBgQbCZwBLAhzAY4DY-gEAYoCwBaIA6IB0RQr6BVg0NjoAYgDIJMR7AEQxBX2AZcCPBTcAd4DHQzOA5AGrAMNkAHMAZ-oAVFHvQKXlgk82gF2IkQQ7AHQBUTsATc47AHkBIwIlQSdAwKIAdgLJLcBFv8BDAiwqQHMnrcFHvn-Ad2BASiWATS1DvAGCCXXAsACVOgPwyftKvBC7QLHAWkPHqAHkSzihQEY1t3UFL0DjAPUAdYEnQWFAdMDc6cV5hrzBagBxQcCCQKPS92OBu0VA8ABkwkD4gFMOwsCkQPskwWXfesR8ikBxAEEjgG9EKAG-u-cAgIW7gNUnAKUArcDFgLlDcuaBZAEqRNb6ggCBrYDst0ijAHXAgYygwPBAqMDCGkDAbgB3gKWBJ8KAQUBTYAPvRb6TswDA2TCAYuHApgBCL4B1QTQCgjPCrEFvAEDyAJWRwIQ3AGOCYEZhgiWjgoL4wTmC7ME3UTSAdSgAZoERE_ou5EPAQEB9QIBAQFkHpEw6M4Bx4EBFiYCPQEBAVY0swOuAQEWvQnwBggl1wLAAlSQCxTBAU9JayBgiAu8Bv0VAu0qlwECFtET8C1xnAFDHacBIGkPHsQFzAEQ7BXWBJgBxQOMC9ABBhCdRJgB4A8G-y6vAR0YCf_IZP__yGSMDBTIZP__yGT_jAwUAP___wD__4wMFP9kZP__ZGSMDBQNstP_Co6pjAwUyGT__6BQzIwMFP9kZP_MUFCMDBTf3Q7_srELjAwUAP___wDMzIwMFAAAAgIAAAQCAgICAgACAgIAAgAGCAILCwMLDQILAgoOCxEICAoODg4GCwsOCggKAAIIDgQCAAACBAICAAIEAgACAgIAAgICBAAABAQEBAYCAgQCBAIABAYCBAIEAAAEBAIEAgACAgIEAgQCAgACAgUAAgICAgACAwICAgICAgICAgICBgYEAgYCAgYGBgYGBgYGBgYGBgAABgAABAIGBgYGAgICAgIGBgAGBgYGBgYGAgYGBgYGBgYGBgYGBgICBAYGBgICBgIGBgYGBgICAgICBgoCBgICAAYGBgIAAgIDBAMAAgACAAMDBgIGAgYGAgYCBgYCBgYODg4ODg4ODgoIDgoICgoODg4ODgoKDg4ODgkLCwsKCg4ODggIDgoICg8KCgsLDg4OCggOCAgKDgoLCwsICAoODggKCA4OCg4IDg4ICAoKFAhDIFRSSVBMRQk5IHBhdGhpbmcSZGJsIGRibCBzaW5nbGUgOSBOAUMIYiB0cmlwbGUBRAFCAUENMSBvciAyIGZ1cmllcwtzaW5nbGUgZ3JlZwNkYmwPMSBnbyAybmQgaXNsYW5kEXNpbmdsZSAybmQgaXNsYW5kGVRXSU4gRlVSSUVTIElGIE5PVCBUUklQTEUJQyBQQVRISU5HBlRSSVBMRQpDSEVDSyBIRVJFC1NJTkdMRSBHUkVHGURPVUJMRSBQSU5HIFBBVEhJTkcgU1VSR0UIQiBUUklQTEUAAQIDBAUEBgcHCAkKCwwKDQ4PBxAREhMOBg"

  setup do
    %{preset: share_preset!(register_user!(), %{kind: :tile_marker, content: @araxxor})}
  end

  test "draws the tiles and labels on the world map, floor by floor", %{
    conn: conn,
    preset: preset
  } do
    conn
    |> visit(~p"/presets/#{preset}")
    |> wait_for_liveview()
    |> assert_has("#tile-map .leaflet-container")
    |> assert_has("#tile-map .leaflet-tile-pane img")
    |> refute_has("#tile-map .tile-label")
    |> click_button("Show 1st floor")
    |> assert_has("#tile-map button.btn-primary", text: "1st floor")
    |> assert_has("#tile-map .tile-label", text: "walk nw")
    |> assert_has("#tile-map .tile-label", text: "surge from here")
  end

  test "tiles spread over the whole world still map, and the rest of the page loads",
       %{conn: conn} do
    preset = share_preset!(register_user!(), %{kind: :tile_marker, content: @spread_out})

    conn
    |> visit(~p"/presets/#{preset}")
    |> wait_for_liveview()
    |> assert_has("#tile-map .leaflet-tile-pane img")
    |> assert_has("#comments-empty", text: "No comments yet.")
  end
end
