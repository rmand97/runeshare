defmodule RuneshareWeb.AccountLiveTest do
  use RuneshareWeb.ConnCase, async: true

  alias Runeshare.Sharing

  test "signed-out visitors are sent to sign in", %{conn: conn} do
    conn
    |> visit(~p"/account")
    |> assert_path(~p"/sign-in")
  end

  describe "your shares" do
    test "lists only your own presets with version and update time", %{conn: conn} do
      user = register_user!(email: "me@example.com")
      share_preset!(user, %{title: "Vorago rotation timer"})
      share_preset!(user, %{kind: :tile_marker, title: "Raksha tiles"})
      share_preset!(register_user!(), %{title: "Someone else's alarm"})

      conn
      |> log_in_user(user)
      |> visit(~p"/account")
      |> assert_has("#profile", text: "me@example.com")
      |> assert_has("#my-presets a", text: "Vorago rotation timer", timeout: 2_000)
      |> assert_has("#my-presets a", text: "Raksha tiles")
      |> assert_has("#my-presets", text: "v1")
      |> assert_has("#my-presets time", text: "Updated just now")
      |> refute_has("#my-presets a", text: "Someone else's alarm")
    end

    test "shows how to share something when empty", %{conn: conn} do
      conn
      |> log_in_user(register_user!())
      |> visit(~p"/account")
      |> assert_has("#my-presets", text: "You haven't shared anything yet.", timeout: 2_000)
    end
  end

  describe "liked" do
    test "lists presets you liked", %{conn: conn} do
      user = register_user!()
      preset = share_preset!(register_user!(name: "Zezima"), %{title: "Telos enrage alarm"})
      share_preset!(register_user!(), %{title: "Not liked"})
      Sharing.like_preset!(preset.id, actor: user)

      conn
      |> log_in_user(user)
      |> visit(~p"/account")
      |> assert_has("#liked-presets a", text: "Telos enrage alarm", timeout: 2_000)
      |> assert_has("#liked-presets a[href='/u/#{preset.author_id}']", text: "Zezima")
      |> refute_has("#liked-presets a", text: "Not liked")
    end

    test "shows 20 likes at first and the rest on request", %{conn: conn} do
      fan = register_user!()
      # Several authors: sharing is rate limited to 10 an hour per user.
      for author <- for(_ <- 1..3, do: register_user!()), n <- 1..9 do
        preset = share_preset!(author, %{title: "Liked #{author.id} #{n}"})
        Sharing.like_preset!(preset.id, actor: fan)
      end

      conn
      |> log_in_user(fan)
      |> visit(~p"/account")
      |> assert_has("#liked-presets-list li[data-phx-stream]", count: 20, timeout: 2_000)
      |> assert_has("#more-liked", text: "(7 more)")
      |> click_button("#more-liked", "Show more")
      |> assert_has("#liked-presets-list li[data-phx-stream]", count: 27, timeout: 2_000)
      |> refute_has("#more-liked")
    end

    test "says when nothing is liked", %{conn: conn} do
      conn
      |> log_in_user(register_user!())
      |> visit(~p"/account")
      |> assert_has("#liked-presets", text: "Nothing liked yet.", timeout: 2_000)
    end
  end

  describe "profile" do
    test "renames yourself", %{conn: conn} do
      conn
      |> log_in_user(register_user!(name: "Old Name"))
      |> visit(~p"/account")
      |> fill_in("Display name", with: "Zezima")
      |> click_button("Save name")
      |> assert_has("#profile-name", text: "Zezima")
      |> assert_has("header", text: "Zezima")
      |> assert_has("#toast-group [role=alert]", text: "Display name saved", timeout: 1_000)
    end

    test "rejects a too-short name", %{conn: conn} do
      conn
      |> log_in_user(register_user!(name: "Old Name"))
      |> visit(~p"/account")
      |> fill_in("Display name", with: "Z")
      |> click_button("Save name")
      |> assert_has("#profile-form", text: "length must be greater than or equal to 2")
      |> assert_has("#profile-name", text: "Old Name")
    end
  end
end
