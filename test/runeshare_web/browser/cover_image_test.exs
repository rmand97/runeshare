defmodule RuneshareWeb.Browser.CoverImageTest do
  use PhoenixTest.Playwright.Case, async: true
  use RuneshareWeb, :verified_routes

  import Runeshare.Test.Builders
  import RuneshareWeb.BrowserHelpers

  alias AshStorage.Service.Test, as: Store
  alias Runeshare.Sharing

  test "the browser re-encodes the picked image before uploading it", %{conn: conn} do
    user = register_user!()

    conn
    |> log_in_user(user)
    |> visit(~p"/tile-markers/new")
    |> fill_in("Title", with: "Shrunk cover")
    |> fill_in("Import string", with: tile_marker_token())
    |> upload("Cover image (optional)", cover_image_path())
    |> assert_has("#cover-image-picker ~ div p", text: "cover.webp")
    |> click_button("Save preset")
    |> assert_has("h1", text: "Shrunk cover")

    [preset] = Sharing.list_my_presets!(actor: user)
    "http://test.local/storage/" <> key = Sharing.get_preset!(preset.id).cover_image_url
    {:ok, bytes} = Store.download(key, [])

    assert <<"RIFF", _size::binary-size(4), "WEBP", _rest::binary>> = bytes
  end
end
