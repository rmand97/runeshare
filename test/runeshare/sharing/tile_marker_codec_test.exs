defmodule Runeshare.Sharing.TileMarkerCodecTest do
  use ExUnit.Case, async: true

  import Runeshare.Test.Builders, only: [tile_marker_token: 0]

  alias Runeshare.Sharing.TileMarkerCodec

  # Real presets from the RuneScape Wiki's Guide:Tilemarkers, one per format variant.
  # Delta-coded coordinates, no labels, upstairs.
  @twin_furies "TM2AgtUd2luIEZ1cmllcwG-MMxuAZ6Ar_9-ZoyMDBQA"
  # Morton-coded coordinates, labels inline.
  @wildy_agility "TM2IQ1XaWxkeSBBZ2lsaXR5A9-2_gbqBlwDZmT__1JQzIwJFPL_ZP_CzFCMDBTy_2T_wsxQjAkUAQMFBVN1cmdlCURpdmUgaGVyZQREaXZl"
  # Morton-coded coordinates, labels through a dictionary.
  @forgotten_painting "TM2MRxGb3Jnb3R0ZW4gUGFpbnRpbmcgRGlnIFNwb3RzB6H_2gWh9hK1wgT91wWHH40h5tQBAvX_AP_EzACMCRT1_wD_xMwAjAEUAQMBAQEBAQEbRm9yZ290dGVuIFBhaW50aW5nIERpZyBTcG90AAAAAAAAAA"
  # Morton-coded coordinates, prefix-compressed label dictionary.
  @solak "TM2cQ9Tb2xhayBBcm1zL0xlZ3MUl8fYCYUGAxAOMQELmgGrA8gFCTQBAQEDBgLqAQXJcgD_oVsAjAIUTP8A_z3MAIwCFBPL2f8Poq6MAhT_AAD_zAAAjAIU2RO7_64PlowCFAEBAQMDBAQEBwEDCQQFBAQDBAQHCQAEQ29yZQANRCBCcmVhdGggYXJtcwEEdW1teQAITGVmdCBBcm0FA0xlZwAFTWluZXMACVJpZ2h0IEFybQYDTGVnAAhTdW5zaGluZQUIAQQDBQUHAgAGBQ"

  test "reads a preset's name and tiles, with floor and colours" do
    assert {:ok, %{name: "Twin Furies", tiles: [tile]}} = TileMarkerCodec.decode(@twin_furies)

    assert %{plane: 1, label: nil, outline_alpha: 255, filled: true} = tile
    assert tile.outline =~ ~r/\A#[0-9a-f]{6}\z/
    assert tile.fill_alpha < 255
  end

  test "reads Morton-coded coordinates and inline labels" do
    assert {:ok, %{name: "Wildy Agility", tiles: tiles}} = TileMarkerCodec.decode(@wildy_agility)

    assert [
             %{x: 2995, z: 3935, plane: 0, label: "Surge"},
             %{label: "Dive here"},
             %{label: "Dive"}
           ] =
             tiles
  end

  test "reads labels from a dictionary" do
    assert {:ok, %{tiles: tiles}} = TileMarkerCodec.decode(@forgotten_painting)

    assert Enum.count(tiles) == 7
    assert Enum.all?(tiles, &(&1.label == "Forgotten Painting Dig Spot"))
  end

  test "reads a prefix-compressed label dictionary" do
    assert {:ok, %{name: "Solak Arms/Legs", tiles: tiles}} = TileMarkerCodec.decode(@solak)

    labels = tiles |> Enum.map(& &1.label) |> Enum.reject(&is_nil/1) |> Enum.uniq()
    assert "Left Arm" in labels
    assert "Left Leg" in labels
    assert "Right Leg" in labels
  end

  test "refuses anything that isn't a complete token" do
    for content <- [
          "hello",
          "TM2",
          "TM2!!!!",
          tile_marker_token(),
          String.slice(@wildy_agility, 0..-6//1),
          @wildy_agility <> "AA"
        ] do
      assert TileMarkerCodec.decode(content) == :error, content
      assert Enum.empty?(TileMarkerCodec.tiles(content))
    end
  end
end
