defmodule RuneshareWeb.Browser.CopyPresetTest do
  use PhoenixTest.Playwright.Case,
    async: true,
    browser_context_opts: [permissions: ["clipboard-read", "clipboard-write"]]

  use RuneshareWeb, :verified_routes

  import Runeshare.Test.Builders

  alias Runeshare.Sharing

  test "copying the import string puts it on the clipboard and counts the copy", %{conn: conn} do
    preset = share_preset!(register_user!(), %{content: watchdog_export("Telos enrage")})

    conn
    |> visit(~p"/presets/#{preset}")
    |> assert_has("#copy-count", text: "Copied 0×")
    |> click_button("#copy-preset", "Copy string")
    |> assert_has("#copy-preset", text: "Copied!")
    |> assert_has("#copy-count", text: "Copied 1×")
    |> evaluate("navigator.clipboard.readText()", &assert(&1 == preset.content))

    assert Sharing.get_preset!(preset.id).copy_count == 1
  end
end
