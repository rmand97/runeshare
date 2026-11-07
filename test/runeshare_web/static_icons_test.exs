defmodule RuneshareWeb.StaticIconsTest do
  # Not async: writes into priv/static for the duration of the test.
  use RuneshareWeb.ConnCase, async: false

  # In prod, `mix phx.digest` adds fingerprinted copies ("favicon-<hash>.ico")
  # and the layout links those. They must be served, not 404.
  setup do
    dir = Application.app_dir(:runeshare, "priv/static")

    copies =
      for {source, digested} <- [
            {"favicon.ico", "favicon-0123456789abcdef.ico"},
            {"favicon.svg", "favicon-0123456789abcdef.svg"},
            {"apple-touch-icon.png", "apple-touch-icon-0123456789abcdef.png"}
          ] do
        path = Path.join(dir, digested)
        File.cp!(Path.join(dir, source), path)
        {digested, path}
      end

    on_exit(fn -> Enum.each(copies, fn {_name, path} -> File.rm(path) end) end)
    %{names: Enum.map(copies, &elem(&1, 0))}
  end

  test "digested favicons and the touch icon are served", %{conn: conn, names: names} do
    for name <- names do
      assert conn |> get("/" <> name) |> response(200)
    end
  end
end
