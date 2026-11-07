defmodule RuneshareWeb.ErrorHTMLTest do
  use RuneshareWeb.ConnCase, async: true

  import Phoenix.Template, only: [render_to_string: 4]

  test "404 explains the page is missing and links back into the site" do
    html = render_to_string(RuneshareWeb.ErrorHTML, "404", "html", %{})

    assert html =~ "<title>Not Found · RuneShare</title>"
    assert html =~ "may have been deleted or hidden"
    assert html =~ ~s(href="/watchdog")
    assert html =~ ~s(<meta name="robots" content="noindex">)
    refute html =~ "<script"
  end

  test "500 says it's our fault" do
    html = render_to_string(RuneshareWeb.ErrorHTML, "500", "html", %{})

    assert html =~ "Internal Server Error"
    assert html =~ "went wrong on our side"
  end

  test "other statuses get their name and a generic message" do
    assert render_to_string(RuneshareWeb.ErrorHTML, "400", "html", %{}) =~ "Bad Request"
    assert render_to_string(RuneshareWeb.ErrorHTML, "403", "html", %{}) =~ "Forbidden"
  end

  test "a preset that doesn't exist answers 404 with the error page", %{conn: conn} do
    {404, _headers, body} =
      assert_error_sent 404, fn ->
        get(conn, ~p"/presets/00000000-0000-0000-0000-000000000000")
      end

    assert body =~ "may have been deleted or hidden"
  end
end
