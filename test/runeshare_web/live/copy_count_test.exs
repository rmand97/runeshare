defmodule RuneshareWeb.CopyCountTest do
  use RuneshareWeb.ConnCase, async: true

  import Phoenix.LiveViewTest, only: [live: 2, render_async: 2, render_hook: 3]

  # The card's copy count, read from the rendered page (a row may show it twice:
  # phone and desktop layouts).
  defp copies(html, preset) do
    html
    |> LazyHTML.from_fragment()
    |> LazyHTML.query(~s([id$="-#{preset.id}"] [title="Copies"]))
    |> Enum.map(&(&1 |> LazyHTML.text() |> String.trim()))
    |> Enum.uniq()
  end

  # A visit first, so the session carries the visitor id copies are counted by.
  defp live_with_visitor(conn, path) do
    {:ok, view, _html} = conn |> get(path) |> live(path)
    view
  end

  # Renders once the card is on screen. Shares from tests running alongside
  # broadcast on the same topics and restart the page's load, so one
  # render_async can return while a newer load is still running.
  defp render_card(view, preset, tries \\ 20) do
    html = render_async(view, 2_000)

    if Enum.empty?(copies(html, preset)) and tries > 0,
      do: render_card(view, preset, tries - 1),
      else: html
  end

  for {name, path} <- [{"home page", "/"}, {"listing", "/watchdog"}] do
    test "copying from the #{name} raises the card's copy count", %{conn: conn} do
      preset = share_preset!(register_user!())
      view = live_with_visitor(conn, unquote(path))

      assert view |> render_card(preset) |> copies(preset) == ["0"]
      assert view |> render_hook("copied", %{"id" => preset.id}) |> copies(preset) == ["1"]
      assert view |> render_hook("copied", %{"id" => preset.id}) |> copies(preset) == ["1"]
    end
  end

  test "a copy of a preset that is gone leaves the page as it was", %{conn: conn} do
    view = live_with_visitor(conn, "/")

    assert render_hook(view, "copied", %{"id" => Ecto.UUID.generate()}) =~ "RuneShare"
  end
end
