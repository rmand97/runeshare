defmodule RuneshareWeb.Browser.MobileTapTest do
  use PhoenixTest.Playwright.Case,
    async: true,
    browser_context_opts: [viewport: %{width: 375, height: 740}, has_touch: true, is_mobile: true]

  use RuneshareWeb, :verified_routes

  import Runeshare.Test.Builders
  import RuneshareWeb.BrowserHelpers

  # Real browser; skipped in CI (`mix test --exclude playwright`).
  @moduletag :playwright

  # Clicks whatever a finger would hit at a point relative to `selector`'s box, so the
  # assertions cover the stretched row link and the enlarged hit areas, not the DOM.
  @tap_near """
  ([selector, dx, dy]) => {
    const box = document.querySelector(selector).getBoundingClientRect()
    const hit = document.elementFromPoint(box.left + dx, box.top + dy)
    const target = hit.closest("a, button, summary")
    return target ? (target.getAttribute("aria-label") || target.textContent.trim()) : null
  }
  """

  setup do
    preset = share_preset!(register_user!(), %{title: "Row tap target", tags: ["telos"]})
    %{row: "#presets-#{preset.id}"}
  end

  test "small controls answer taps just outside their edge", %{conn: conn, row: row} do
    conn
    |> visit(~p"/watchdog")
    |> wait_for_liveview()
    |> assert_has(row)
    # 10px above the 21px copy button.
    |> evaluate(@tap_near, [is_function: true, arg: ["#{row} button", 10, -10]], fn hit ->
      assert hit == "Copy import string"
    end)
    # 6px above a tag badge.
    |> evaluate(@tap_near, [is_function: true, arg: ["#{row} a.badge", 5, -6]], fn hit ->
      assert hit == "telos"
    end)
    # The row's like count is plain text: the tap lands on the row's title link.
    |> evaluate(@tap_near, [is_function: true, arg: ["#{row} [title=Likes]", 2, 4]], fn hit ->
      assert hit == "Row tap target"
    end)
  end

  test "tapping a row away from its title opens the preset", %{conn: conn, row: row} do
    conn
    |> visit(~p"/watchdog")
    |> wait_for_liveview()
    # The listing streams in after mount; wait for the row before measuring it.
    |> assert_has("#{row} [title=Likes]")
    |> evaluate("""
    const box = document.querySelector('#{row} [title=Likes]').getBoundingClientRect()
    document.elementFromPoint(box.left + 2, box.top + 4).click()
    """)
    |> assert_has("h1", text: "Row tap target")
  end
end
