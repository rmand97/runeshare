defmodule RuneshareWeb.PresetLiveTest do
  use RuneshareWeb.ConnCase, async: true

  # PhoenixTest can't blur a field; the blur-dependent test drives the LiveView directly.
  import Phoenix.LiveViewTest,
    only: [live: 2, form: 3, element: 2, render_change: 1, render_blur: 1]

  alias Runeshare.Sharing

  describe "home" do
    test "shows the newest preset of each kind and the share counts", %{conn: conn} do
      user = register_user!()
      share_preset!(user, %{title: "Vorago rotation timer"})
      share_preset!(user, %{kind: :tile_marker, title: "Zamorak P4 tiles"})

      conn
      |> visit(~p"/")
      |> assert_has("#newest-watchdog_alarm a", text: "Vorago rotation timer", timeout: 2_000)
      |> assert_has("#newest-tile_marker a", text: "Zamorak P4 tiles", timeout: 2_000)
      |> assert_has("#stat-watchdog_alarm", text: "1", timeout: 2_000)
    end

    test "says when a kind has nothing shared yet", %{conn: conn} do
      conn
      |> visit(~p"/")
      |> assert_has("#newest-tile_marker", text: "Nothing shared yet.", timeout: 2_000)
    end
  end

  describe "listing" do
    test "shows only its kind, with version and counts, and can be searched", %{conn: conn} do
      user = register_user!()
      share_preset!(user, %{title: "Vorago rotation timer"})
      share_preset!(user, %{title: "Telos enrage alarm"})
      share_preset!(user, %{kind: :tile_marker, title: "Zamorak P4 tiles"})

      conn
      |> visit(~p"/watchdog")
      |> assert_has("#presets a", text: "Vorago rotation timer", timeout: 2_000)
      |> assert_has("#presets", text: "v1")
      |> refute_has("#presets a", text: "Zamorak P4 tiles")
      |> fill_in("Search by title", with: "telos")
      |> assert_has("#presets a", text: "Telos enrage alarm", timeout: 2_000)
      |> refute_has("#presets a", text: "Vorago rotation timer", timeout: 2_000)
    end

    test "sorts by most liked", %{conn: conn} do
      author = register_user!()
      fan = register_user!()
      older = share_preset!(author, %{title: "Older but loved"})
      share_preset!(author, %{title: "Newer and ignored"})
      Sharing.like_preset!(older.id, actor: fan)

      conn
      |> visit(~p"/watchdog")
      |> assert_has("#presets-body tr:nth-child(2) a", text: "Newer and ignored", timeout: 2_000)
      |> click_link("Most liked")
      |> assert_path(~p"/watchdog", query_params: %{sort: "most_liked"})
      |> assert_has("#presets-body tr:nth-child(2) a", text: "Older but loved", timeout: 2_000)
    end

    test "sorts by most copied", %{conn: conn} do
      author = register_user!()
      copied = share_preset!(author, %{title: "Older but copied"})
      share_preset!(author, %{title: "Newer and uncopied"})
      Sharing.record_copy!(copied.id, "anon:one")
      Sharing.record_copy!(copied.id, "anon:two")

      conn
      |> visit(~p"/watchdog")
      |> click_link("Most copied")
      |> assert_path(~p"/watchdog", query_params: %{sort: "most_copied"})
      |> assert_has("#presets-body tr:nth-child(2) a", text: "Older but copied", timeout: 2_000)
      |> assert_has("#presets-body tr:nth-child(2) [title=Copies]", text: "2")
    end

    test "filters by tag, and the tag can be cleared", %{conn: conn} do
      author = register_user!()
      share_preset!(author, %{title: "Vorago rotation timer", tags: ["vorago"]})
      share_preset!(author, %{title: "Telos enrage alarm", tags: ["telos"]})

      conn
      |> visit(~p"/watchdog?tag=vorago&sort=most_liked")
      |> assert_has("#active-tag", text: "vorago")
      |> assert_has("#presets a", text: "Vorago rotation timer", timeout: 2_000)
      |> refute_has("#presets a", text: "Telos enrage alarm")
      |> click_link("Most copied")
      |> assert_path(~p"/watchdog", query_params: %{sort: "most_copied", tag: "vorago"})
      |> click_link("[aria-label='Clear tag vorago']", "")
      |> assert_has("#presets a", text: "Telos enrage alarm", timeout: 2_000)
      |> refute_has("#active-tag")
    end

    test "says when nothing matches", %{conn: conn} do
      conn
      |> visit(~p"/tile-markers?q=nothing-like-this")
      |> assert_has("#presets", text: "No presets found.", timeout: 2_000)
    end
  end

  describe "sharing" do
    test "signed-out visitors are sent to sign in", %{conn: conn} do
      conn
      |> visit(~p"/watchdog/new")
      |> assert_path(~p"/sign-in")
    end

    test "a signed-in user shares a tile marker preset", %{conn: conn} do
      conn
      |> log_in_user(register_user!())
      |> visit(~p"/tile-markers/new")
      |> fill_in("Title", with: "Raksha tiles")
      |> fill_in("Import string", with: tile_marker_token())
      |> click_button("Save preset")
      |> assert_has("h1", text: "Raksha tiles")
      |> assert_has(".badge", text: "Tile markers")
    end

    test "a field's errors wait until the user leaves it, then update live", %{conn: conn} do
      {:ok, view, _html} = conn |> log_in_user(register_user!()) |> live(~p"/watchdog/new")
      too_short = ~r/at least 3|greater than or equal to 3/

      refute view |> form("#preset-form", form: %{title: "V"}) |> render_change() =~ too_short
      assert view |> element("#form_title") |> render_blur() =~ too_short
      assert view |> form("#preset-form", form: %{title: "Vo"}) |> render_change() =~ too_short
      refute view |> form("#preset-form", form: %{title: "Vor"}) |> render_change() =~ too_short
    end

    test "a failed save shows every field's errors", %{conn: conn} do
      conn
      |> log_in_user(register_user!())
      |> visit(~p"/watchdog/new")
      |> fill_in("Title", with: "V")
      |> fill_in("Import string", with: watchdog_export())
      |> refute_has("p.text-error")
      |> click_button("Save preset")
      |> assert_has("p.text-error")
    end

    test "a cover image is uploaded with the preset and shown on it and in the listing", %{
      conn: conn
    } do
      conn
      |> log_in_user(register_user!())
      |> visit(~p"/tile-markers/new")
      |> fill_in("Title", with: "Raksha tiles")
      |> fill_in("Import string", with: tile_marker_token())
      |> upload("Cover image (optional)", cover_image_path())
      |> click_button("Save preset")
      |> assert_has("h1", text: "Raksha tiles")
      |> assert_has("img#cover-image[alt='Cover image for Raksha tiles']")
      |> visit(~p"/tile-markers")
      |> assert_has("#presets-body img[src^='http://test.local/storage/']", timeout: 2_000)
    end

    test "a file that isn't really an image is refused", %{conn: conn} do
      fake = temp_file!("<html>not an image</html>")
      File.rename!(fake, fake <> ".png")

      conn
      |> log_in_user(register_user!())
      |> visit(~p"/tile-markers/new")
      |> fill_in("Title", with: "Raksha tiles")
      |> fill_in("Import string", with: tile_marker_token())
      |> upload("Cover image (optional)", fake <> ".png")
      |> click_button("Save preset")
      |> assert_has("p.text-error", text: "must be a JPEG, PNG or WebP image")
    end

    test "tags are previewed while typing and shown in the listing", %{conn: conn} do
      conn
      |> log_in_user(register_user!())
      |> visit(~p"/watchdog/new")
      |> fill_in("Title", with: "Vorago hard mode alarms")
      |> fill_in("Import string", with: watchdog_export())
      |> fill_in("Tags (optional)", with: "Vorago, hard mode")
      |> assert_has("#tag-preview .badge", text: "hard-mode")
      |> click_button("Save preset")
      |> assert_has("h1", text: "Vorago hard mode alarms")

      [preset] = Sharing.list_presets!(:watchdog_alarm, %{tag: "vorago"})
      assert preset.tags == ["vorago", "hard-mode"]

      conn
      |> visit(~p"/watchdog")
      |> assert_has("#presets a.badge", text: "hard-mode", timeout: 2_000)
    end

    test "warns when the exact string is already shared", %{conn: conn} do
      other = register_user!(name: "Zezima")
      share_preset!(other, %{title: "Original Raksha tiles", kind: :tile_marker})

      conn
      |> log_in_user(register_user!())
      |> visit(~p"/tile-markers/new")
      |> fill_in("Import string", with: tile_marker_token())
      |> assert_has("#duplicate-warning", text: "This exact string is already shared as")
      |> assert_has("#duplicate-warning a", text: "Original Raksha tiles")
      |> assert_has("#duplicate-warning", text: "by Zezima")
    end

    test "shows the rate-limit error", %{conn: conn} do
      user = register_user!()
      for n <- 1..10, do: share_preset!(user, %{title: "Alarm #{n}"})

      conn
      |> log_in_user(user)
      |> visit(~p"/watchdog/new")
      |> fill_in("Title", with: "One too many")
      |> fill_in("Import string", with: watchdog_export())
      |> click_button("Save preset")
      |> assert_has("#form-errors", text: "you're doing that too often")
    end
  end

  describe "editing" do
    test "saving an edit creates the next version", %{conn: conn} do
      user = register_user!()
      preset = share_preset!(user, %{title: "Vorago rotation timer"})

      conn
      |> log_in_user(user)
      |> visit(~p"/presets/#{preset}/edit")
      |> assert_has("#current-version", text: "v1")
      |> assert_has("#next-version", text: "saving keeps v1")
      |> fill_in("Title", with: "Vorago rotation timer (hard mode)")
      |> assert_has("#next-version", text: "Saving will create v2")
      |> click_button("Save preset")
      |> assert_has("h1", text: "Vorago rotation timer (hard mode)")

      assert Sharing.get_preset!(preset.id).version == 2
    end

    test "stores the change note on the new version", %{conn: conn} do
      user = register_user!()
      preset = share_preset!(user)

      conn
      |> log_in_user(user)
      |> visit(~p"/presets/#{preset}/edit")
      |> fill_in("What changed? (optional)", with: "Added the P5 enrage alert")
      |> click_button("Save preset")
      |> assert_has("h1", text: preset.title)

      assert [%{number: 2, note: "Added the P5 enrage alert"} | _older] =
               Sharing.list_preset_versions!(preset.id)
    end

    test "the cover image can be removed", %{conn: conn} do
      user = register_user!()
      preset = share_preset!(user, %{cover_image: cover_image()})

      conn
      |> log_in_user(user)
      |> visit(~p"/presets/#{preset}/edit")
      |> assert_has("#current-cover-image img")
      |> check("Remove the current image")
      |> click_button("Save preset")
      |> assert_has("h1", text: preset.title)
      |> refute_has("img#cover-image")
    end

    test "doesn't warn about the preset's own string", %{conn: conn} do
      user = register_user!()
      preset = share_preset!(user)

      conn
      |> log_in_user(user)
      |> visit(~p"/presets/#{preset}/edit")
      |> fill_in("Import string", with: preset.content)
      |> refute_has("#duplicate-warning")
    end
  end
end
