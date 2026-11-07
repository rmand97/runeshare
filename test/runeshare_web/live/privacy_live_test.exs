defmodule RuneshareWeb.PrivacyLiveTest do
  use RuneshareWeb.ConnCase, async: true

  test "the privacy page explains what is stored and how to delete it", %{conn: conn} do
    conn
    |> visit(~p"/privacy")
    |> assert_has("h1", text: "Privacy")
    |> assert_has("#privacy", text: "email address")
    |> assert_has("#privacy", text: "don't keep the provider's access tokens")
    |> assert_has("#privacy a[href='/account']", text: "your account page")
    |> assert_has("#privacy a#privacy-contact[href='mailto:raflnatorr.gaming@gmail.com']")
    |> assert_has(
      "#privacy a#privacy-discord[href='https://discord.com/users/158185574702907392']",
      text: "rafl1772"
    )
  end

  test "every page's footer links to it", %{conn: conn} do
    conn
    |> visit(~p"/watchdog")
    |> assert_has("footer a#footer-privacy[href='/privacy']", text: "Privacy")
  end
end
