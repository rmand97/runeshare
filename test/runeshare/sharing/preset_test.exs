defmodule Runeshare.Sharing.PresetTest do
  use Runeshare.DataCase, async: true

  alias Runeshare.Sharing

  describe "share_preset" do
    test "a signed-in user shares a preset as its author" do
      user = register_user!()

      preset = share_preset!(user, %{kind: :tile_marker, title: "Zamorak P4 tiles"})

      assert preset.author_id == user.id
      assert preset.kind == :tile_marker
    end

    test "anonymous visitors cannot share" do
      assert {:error, %Ash.Error.Forbidden{}} =
               Sharing.share_preset(%{
                 kind: :watchdog_alarm,
                 title: "Nope",
                 content: watchdog_export()
               })
    end

    test "tile marker presets must be Tilemarkers TM2 tokens" do
      user = register_user!()

      assert {:error, %Ash.Error.Invalid{}} =
               Sharing.share_preset(%{kind: :tile_marker, title: "Junk", content: "not a token"},
                 actor: user
               )

      preset = share_preset!(user, %{kind: :tile_marker, content: " #{tile_marker_token()}\n"})
      assert preset.content == tile_marker_token()

      assert {:error, %Ash.Error.Invalid{}} =
               Sharing.edit_preset(preset, %{content: "still not a token"}, actor: user)
    end

    test "watchdog presets must be Watchdog JSON exports" do
      user = register_user!()

      assert {:error, %Ash.Error.Invalid{}} =
               Sharing.share_preset(%{kind: :watchdog_alarm, title: "Junk", content: "WD1:abc"},
                 actor: user
               )

      assert {:error, %Ash.Error.Invalid{}} =
               Sharing.share_preset(
                 %{
                   kind: :watchdog_alarm,
                   title: "No entries",
                   content: ~s({"schemaVersion":1,"entries":[]})
                 },
                 actor: user
               )

      assert %{kind: :watchdog_alarm} = share_preset!(user, %{content: watchdog_export("Vorago")})
    end

    test "rejects an unknown kind and a blank import string" do
      user = register_user!()

      assert {:error, %Ash.Error.Invalid{}} =
               Sharing.share_preset(%{kind: :bogus, title: "Bad kind", content: "x"}, actor: user)

      assert {:error, %Ash.Error.Invalid{}} =
               Sharing.share_preset(%{kind: :tile_marker, title: "Blank", content: "  "},
                 actor: user
               )
    end
  end

  describe "list_presets" do
    test "returns only the requested kind, newest first, readable without signing in" do
      user = register_user!()
      older = share_preset!(user, %{title: "Older alarm"})
      newer = share_preset!(user, %{title: "Newer alarm"})
      share_preset!(user, %{kind: :tile_marker, title: "Some tiles"})

      ids = Enum.map(Sharing.list_presets!(:watchdog_alarm), & &1.id)

      assert ids == [newer.id, older.id]
    end

    test "search matches titles case-insensitively" do
      user = register_user!()
      share_preset!(user, %{title: "Vorago rotations"})
      share_preset!(user, %{title: "Telos enrage"})

      assert [%{title: "Vorago rotations"}] =
               Sharing.list_presets!(:watchdog_alarm, %{search: "VORAGO"})
    end

    test "hides other users' email addresses on the author" do
      author = register_user!()
      share_preset!(author)

      [preset] = Sharing.list_presets!(:watchdog_alarm, actor: register_user!())

      assert %Ash.ForbiddenField{} = preset.author.email
      assert preset.author.name == author.name
    end
  end

  describe "edit_preset and delete_preset" do
    test "the author can edit and delete" do
      author = register_user!()
      preset = share_preset!(author)

      edited = Sharing.edit_preset!(preset, %{title: "Renamed"}, actor: author)
      assert edited.title == "Renamed"

      assert :ok = Sharing.delete_preset!(edited, actor: author)
    end

    test "another user can neither edit nor delete" do
      preset = share_preset!(register_user!())
      stranger = register_user!()

      assert {:error, %Ash.Error.Forbidden{}} =
               Sharing.edit_preset(preset, %{title: "Hijacked"}, actor: stranger)

      assert {:error, %Ash.Error.Forbidden{}} = Sharing.delete_preset(preset, actor: stranger)
    end
  end
end
