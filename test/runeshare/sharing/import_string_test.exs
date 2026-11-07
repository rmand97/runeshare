defmodule Runeshare.Sharing.ImportStringTest do
  use ExUnit.Case, async: true

  import Runeshare.Test.Builders, only: [tile_marker_token: 0, watchdog_export: 1]

  alias Runeshare.Sharing.ImportString

  # Exported in-game from Watchdog 1.0.0.
  @real_watchdog_export ~S({"schemaVersion":1,"entries":[{"enabled":true,"name":"Mining - fatigue test","graph":{"connections":[{"fromNode":5,"toPin":"a","fromPin":"gained","toNode":6},{"fromNode":5,"toPin":"in","fromPin":"out","toNode":7},{"fromNode":6,"toPin":"condition","fromPin":"result","toNode":7},{"fromNode":7,"toPin":"reset","fromPin":"false","toNode":10},{"fromNode":7,"toPin":"dismiss","fromPin":"false","toNode":11},{"fromNode":7,"toPin":"in","fromPin":"true","toNode":10},{"fromNode":10,"toPin":"show","fromPin":"out","toNode":11}],"version":1,"nodes":[{"id":5,"type":"trigger.xp_drop","controls":{"skillFilter":14}},{"id":6,"type":"std.compare","controls":{"a":0,"b":30,"operation":"<="}},{"id":7,"type":"std.branch","controls":{"condition":false}},{"id":9,"type":"action.sound","name":"add sound from out of do once","controls":{"soundId":3964,"bus":"MASTER"}},{"id":10,"type":"std.doonce","controls":{"startClosed":false}},{"id":11,"type":"action.screen_flash","controls":{"outShape":"instant","dismissOn":"both","color":{"r":255,"a":127,"b":0,"g":0},"inShape":"instant"}}]},"kind":"alert","layout":[{"id":5,"y":58,"x":12},{"id":6,"y":61,"x":320},{"id":7,"y":248,"x":74},{"id":9,"y":92,"x":696},{"id":10,"y":251,"x":352},{"id":11,"y":301,"x":623}]}],"pluginVersion":"1.0.0"})

  # Exported in-game from Watchdog 1.0.0, with pluginVersion first and a two-trigger alert.
  @crystal_harps_export ~S({"pluginVersion":"1.0.0","schemaVersion":1,"entries":[{"enabled":true,"name":"Crystal Harps","layout":[{"id":1,"y":16,"x":45},{"id":2,"y":16,"x":424},{"id":3,"y":198,"x":50},{"id":4,"y":198,"x":423}],"kind":"alert","graph":{"nodes":[{"id":1,"controls":{"type":"any","contains":{"mode":"substring","needle":"Your harp is 50% out of tune"}},"type":"trigger.game_message"},{"id":2,"controls":{"bus":"MASTER","soundId":4032},"type":"action.sound"},{"id":3,"controls":{"type":"any","contains":{"mode":"substring","needle":"Your harp is 100% out of tune"}},"type":"trigger.game_message"},{"id":4,"controls":{"bus":"MASTER","soundId":49467},"type":"action.sound"}],"version":1,"connections":[{"toPin":"in","fromPin":"out","fromNode":1,"toNode":2},{"toPin":"in","fromPin":"out","fromNode":3,"toNode":4}]}}]})

  # From the RS Wiki's Tilemarkers guide.
  @real_tile_marker_token "TM2AR5Gb3JpbnRocnkgRHVuZ2VvbiAtIEhlbGxob3VuZHPOAbQwgp4BAAAAAAAAAAAAAAAABQAAAAAAiAAAAAAAAAAAAAAAAAAABAAAAAAAhwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACIAwAAAAAAAAAAAAAAAAAAAAAAAAAAjAAAAAAAAAAAAAAAAAAAAAAAAAAAjAAAAAAAAAAAAAAAAAAAAAADjQAAAAAAAAAAAAAAAAAAkgAAAAAAAAAAAAAAAJYAAAAAAAAAAQCWAAAAAAAAAAAAmQAAAACcAAAAAJwAAACcAAAAAJsAAAAAAJsAAAAAAAX_8QD_zMEAjAkU_3gA_8xgAIwJFO8hC_-_GgmMCRTIZP__oFDMjAkU_3gA_8xgAIwBFAAAAAICAgICAgQGBgQCAgIAAAAAAAAAAgICAgICAgQEAgIAAAAAAAAAAAAAAAQEBAQEBAQGBgQEBAICAAAAAAAAAAAEBAQEBAQEBgQEBAQEAgAAAAAAAAACAgICAgICBAQEBAQEAgAAAAAAAAACAgICAgICBAQEBAQEAgAAAAACAgICAgIEBAQEBAQCAAACAgICAgIEBAQEBAQCAgICAgQEBAQEAAAAAAACAgICCAgAAAICAgAAAgICAAAAAgAAAAAAAAAAAAAAAAAAAAAA"

  describe "Watchdog export versions" do
    test "real exports report the plugin and schema version they were made with" do
      for export <- [@real_watchdog_export, @crystal_harps_export] do
        assert ImportString.watchdog_versions(export) ==
                 %{plugin_version: "1.0.0", schema_version: 1}
      end
    end

    test "an export without pluginVersion still reports its schema version" do
      export =
        "No plugin version"
        |> watchdog_export()
        |> JSON.decode!()
        |> Map.delete("pluginVersion")
        |> JSON.encode!()

      assert ImportString.watchdog_versions(export) == %{plugin_version: nil, schema_version: 1}
    end

    test "anything that isn't a Watchdog export has no versions" do
      for content <- [tile_marker_token(), "not json", ~s({"schemaVersion":1,"entries":[]})] do
        assert ImportString.watchdog_versions(content) == nil
      end
    end
  end

  describe "Watchdog exports" do
    test "the Crystal Harps export is accepted, named and summarised" do
      assert ImportString.check(:watchdog_alarm, @crystal_harps_export) == :ok

      assert ImportString.suggested_title(:watchdog_alarm, @crystal_harps_export) ==
               "Crystal Harps"

      assert [%{name: "Crystal Harps", triggers: ["Game message"], actions: ["Sound"]}] =
               ImportString.watchdog_summary(@crystal_harps_export)
    end

    test "a real export is accepted and its alert names are read" do
      assert ImportString.check(:watchdog_alarm, @real_watchdog_export) == :ok
      assert ImportString.watchdog_names(@real_watchdog_export) == ["Mining - fatigue test"]

      assert ImportString.suggested_title(:watchdog_alarm, @real_watchdog_export) ==
               "Mining - fatigue test"
    end

    test "non-JSON, JSON of the wrong shape and empty exports are rejected" do
      for content <- [
            "WD1:abc",
            ~s({"foo":1}),
            ~s({"schemaVersion":1,"entries":[]}),
            ~s({"schemaVersion":1,"entries":[{"name":"no graph"}]}),
            ~s([1,2,3])
          ] do
        assert {:error, _message} = ImportString.check(:watchdog_alarm, content), content
      end
    end

    test "a tile marker token is not a Watchdog export" do
      assert {:error, _message} = ImportString.check(:watchdog_alarm, tile_marker_token())
    end
  end

  describe "Tilemarkers tokens" do
    test "a real token is accepted and its preset name is read" do
      assert ImportString.check(:tile_marker, @real_tile_marker_token) == :ok

      assert ImportString.suggested_title(:tile_marker, @real_tile_marker_token) ==
               "Forinthry Dungeon - Hellhounds"
    end

    test "junk, quoted tokens and Watchdog JSON are rejected" do
      for content <- ["hello", ~s("#{@real_tile_marker_token}"), "TM2short", watchdog_export("x")] do
        assert {:error, _message} = ImportString.check(:tile_marker, content), content
      end
    end
  end
end
