defmodule RuneshareWeb.AuthorLiveTest do
  use RuneshareWeb.ConnCase, async: true

  alias Runeshare.Sharing

  test "shows the author's presets but not others'", %{conn: conn} do
    author = register_user!(name: "Zezima")
    share_preset!(author, %{title: "Vorago rotation timer", tags: ["vorago"]})
    share_preset!(author, %{kind: :tile_marker, title: "Raksha tiles"})
    share_preset!(register_user!(), %{title: "Someone else's alarm"})

    conn
    |> visit(~p"/u/#{author}")
    |> assert_has("h1", text: "Zezima")
    |> assert_has("#author-presets a", text: "Vorago rotation timer", timeout: 2_000)
    |> assert_has("#author-presets a", text: "Raksha tiles")
    |> assert_has("#author-presets", text: "vorago")
    |> assert_has("#author-stats", text: "Shares")
    |> refute_has("#author-presets a", text: "Someone else's alarm")
    |> refute_has("a", text: "Edit your account")
  end

  test "hidden presets don't show to visitors", %{conn: conn} do
    author = register_user!()
    preset = share_preset!(author, %{title: "Hidden alarm"})
    share_preset!(author, %{title: "Visible alarm"})
    Sharing.hide_preset!(preset, actor: register_admin!())

    conn
    |> log_in_user(register_user!())
    |> visit(~p"/u/#{author}")
    |> assert_has("#author-presets a", text: "Visible alarm", timeout: 2_000)
    |> refute_has("#author-presets a", text: "Hidden alarm")
  end

  test "shows an empty state", %{conn: conn} do
    conn
    |> visit(~p"/u/#{register_user!()}")
    |> assert_has("#author-presets", text: "Nothing shared yet.", timeout: 2_000)
  end

  test "your own page links to your account", %{conn: conn} do
    user = register_user!()

    conn
    |> log_in_user(user)
    |> visit(~p"/u/#{user}")
    |> click_link("Edit your account")
    |> assert_path(~p"/account")
  end
end
