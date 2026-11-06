defmodule Runeshare.Sharing.DiscoveryTest do
  use Runeshare.DataCase, async: true

  alias Runeshare.Sharing
  alias Runeshare.Sharing.ImportString

  describe "tags" do
    test "are normalised and filter the listing" do
      author = register_user!()
      tagged = share_preset!(author, %{title: "Tagged", tags: ["Vorago ", "VORAGO", "Hard Mode"]})
      share_preset!(author, %{title: "Untagged"})

      assert tagged.tags == ["vorago", "hard-mode"]

      nicknamed =
        share_preset!(author, %{title: "Nicknamed", tags: ["Zammy", "rc", "my own tag"]})

      assert nicknamed.tags == ["zamorak", "runecrafting", "my-own-tag"]
      assert [%{title: "Tagged"}] = Sharing.list_presets!(:watchdog_alarm, %{tag: "vorago"})
    end

    test "at most five" do
      assert {:error, %Ash.Error.Invalid{}} =
               Sharing.share_preset(
                 %{
                   kind: :watchdog_alarm,
                   title: "Too many",
                   content: watchdog_export("x"),
                   tags: ~w(a1 b2 c3 d4 e5 f6)
                 },
                 actor: register_user!()
               )
    end
  end

  describe "copies" do
    test "count each visitor once, without bumping the updated date or the version" do
      preset = share_preset!(register_user!())

      Sharing.record_copy!(preset.id, "anon:a")
      Sharing.record_copy!(preset.id, "anon:a")
      Sharing.record_copy!(preset.id, "user:b")

      copied = Sharing.get_preset!(preset.id)
      assert copied.copy_count == 2
      assert copied.version == 1
      assert DateTime.compare(copied.updated_at, preset.updated_at) == :eq
    end

    test "of a hidden preset aren't counted" do
      preset = share_preset!(register_user!())
      Sharing.hide_preset!(preset, actor: register_admin!())

      assert {:error, %Ash.Error.Invalid{}} = Sharing.record_copy(preset.id, "anon:a")
    end

    test "sort the listing by most copied" do
      author = register_user!()
      share_preset!(author, %{title: "Rare"})
      popular = share_preset!(author, %{title: "Popular"})
      Sharing.record_copy!(popular.id, "anon:a")

      assert [%{title: "Popular"}, %{title: "Rare"}] =
               Sharing.list_presets!(:watchdog_alarm, %{sort: :most_copied})
    end
  end

  describe "duplicates" do
    test "finds a preset with the same import string, ignoring surrounding whitespace" do
      original = share_preset!(register_user!(), %{content: watchdog_export("Same")})

      assert [%{id: id}] =
               Sharing.find_duplicate_presets!(:watchdog_alarm, "  " <> watchdog_export("Same"))

      assert id == original.id
      assert [] = Sharing.find_duplicate_presets!(:watchdog_alarm, watchdog_export("Other"))
      assert [] = Sharing.find_duplicate_presets!(:tile_marker, watchdog_export("Same"))
    end
  end

  describe "liked and by-author lists" do
    test "liked shows what the user liked; by_author shows one author's presets" do
      author = register_user!()
      liked = share_preset!(author, %{title: "Liked one"})
      share_preset!(author, %{title: "Not liked"})
      share_preset!(register_user!(), %{title: "Someone else's"})
      fan = register_user!()
      Sharing.like_preset!(liked.id, actor: fan)

      assert [%{title: "Liked one"}] = Sharing.list_liked_presets!(actor: fan)

      assert ["Not liked", "Liked one"] =
               author.id |> Sharing.list_presets_by_author!() |> Enum.map(& &1.title)
    end
  end

  describe "version notes and comment versions" do
    test "an edit's change note is stored on the new version" do
      author = register_user!()
      preset = share_preset!(author)

      Sharing.edit_preset!(preset, %{title: "Fixed", change_note: "Fixed P4 timings"},
        actor: author
      )

      assert [%{number: 2, note: "Fixed P4 timings"}, %{number: 1, note: nil}] =
               Sharing.list_preset_versions!(preset.id)
    end

    test "comments remember which version they were written on" do
      author = register_user!()
      preset = share_preset!(author)
      fan = register_user!()
      Sharing.post_comment!(preset.id, "on v1", actor: fan)
      Sharing.edit_preset!(preset, %{title: "Second take"}, actor: author)
      Sharing.post_comment!(preset.id, "on v2", actor: fan)

      assert [%{preset_version: 1}, %{preset_version: 2}] = Sharing.list_comments!(preset.id)
    end
  end

  describe "rate limits" do
    test "an eleventh comment within five minutes is rejected" do
      preset = share_preset!(register_user!())
      chatty = register_user!()
      for n <- 1..10, do: Sharing.post_comment!(preset.id, "comment #{n}", actor: chatty)

      assert {:error, %Ash.Error.Invalid{}} =
               Sharing.post_comment(preset.id, "one too many", actor: chatty)

      assert %{} = Sharing.post_comment!(preset.id, "someone else", actor: register_user!())
    end
  end

  describe "Watchdog summary" do
    test "names each alert's triggers and actions" do
      export =
        JSON.encode!(%{
          "schemaVersion" => 1,
          "entries" => [
            %{
              "name" => "Mining - fatigue test",
              "graph" => %{
                "nodes" => [
                  %{"type" => "trigger.xp_drop"},
                  %{"type" => "std.compare"},
                  %{"type" => "action.sound"},
                  %{"type" => "action.screen_flash"}
                ]
              }
            }
          ]
        })

      assert [
               %{
                 name: "Mining - fatigue test",
                 triggers: ["XP drop"],
                 actions: ["Sound", "Screen flash"]
               }
             ] = ImportString.watchdog_summary(export)
    end
  end
end
