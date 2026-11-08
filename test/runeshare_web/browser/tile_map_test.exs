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
end
