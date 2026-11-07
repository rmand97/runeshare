defmodule RuneshareWeb.HomeLiveTest do
  use RuneshareWeb.ConnCase, async: true

  test "the front page shows the five newest presets of each kind", %{conn: conn} do
    author = register_user!()
    for n <- 1..6, do: share_preset!(author, %{title: "Alarm #{n}"})

    session =
      Enum.reduce(2..6, visit(conn, ~p"/"), fn n, session ->
        assert_has(session, "#newest-watchdog_alarm-list li", text: "Alarm #{n}", timeout: 2_000)
      end)

    refute_has(session, "#newest-watchdog_alarm-list li", text: "Alarm 1")
  end

  test "a new share pushes the oldest of the five out", %{conn: conn} do
    author = register_user!()
    for n <- 1..5, do: share_preset!(author, %{title: "Alarm #{n}"})

    session =
      conn
      |> visit(~p"/")
      |> assert_has("#newest-watchdog_alarm-list li", text: "Alarm 1", timeout: 2_000)

    share_preset!(author, %{title: "Alarm 6"})

    session
    |> assert_has("#newest-watchdog_alarm-list li", text: "Alarm 6", timeout: 2_000)
    |> assert_has("#newest-watchdog_alarm-list li", text: "Alarm 2")
    |> refute_has("#newest-watchdog_alarm-list li", text: "Alarm 1")
  end

  test "the footer links to the source code", %{conn: conn} do
    conn
    |> visit(~p"/")
    |> assert_has("footer a#footer-source[href='https://github.com/rmand97/runeshare']",
      text: "Source on GitHub"
    )
  end
end
