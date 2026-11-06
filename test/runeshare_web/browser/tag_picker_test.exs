defmodule RuneshareWeb.Browser.TagPickerTest do
  use PhoenixTest.Playwright.Case, async: true
  use RuneshareWeb, :verified_routes

  import Runeshare.Test.Builders
  import RuneshareWeb.BrowserHelpers

  alias Runeshare.Sharing

  # Real browser; skipped in CI (`mix test --exclude playwright`).
  @moduletag :playwright

  test "pick a suggested tag and add a free one with Enter", %{conn: conn} do
    user = register_user!()

    conn
    |> log_in_user(user)
    |> visit(~p"/watchdog/new")
    |> wait_for_liveview()
    |> fill_in("Title", with: "Tag picker test")
    |> fill_in("Import string", with: watchdog_export())
    # fill_in sets the text in one go; typing key by key right as the field gets
    # focus can lose the first key to the picker's focus re-render.
    |> fill_in("Tags (optional)", with: "zammy")
    # Suggestions round-trip through the server (debounced); slow under a busy suite.
    |> assert_has("#form_tags_live_select_component li", text: "zamorak", timeout: 5_000)
    |> click("#form_tags_live_select_component li", "zamorak")
    |> assert_has("#form_tags_live_select_component", text: "zamorak")
    |> fill_in("Tags (optional)", with: "Phase four")
    # The picker ignores Enter until its suggestions for the typed text arrive.
    |> assert_has("#form_tags_live_select_component li", text: "phase-four", timeout: 5_000)
    |> press("#form_tags_text_input", "Enter")
    # Picking closes the dropdown; the tag then shows as it will be saved.
    |> refute_has("#form_tags_live_select_component li")
    |> assert_has("#form_tags_live_select_component", text: "phase-four")
    |> click_button("Save preset")
    |> assert_has("h1", text: "Tag picker test")

    [preset] = Sharing.list_my_presets!(actor: user)
    assert preset.tags == ["zamorak", "phase-four"]
  end
end
