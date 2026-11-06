defmodule RuneshareWeb.LoggingTest do
  use RuneshareWeb.ConnCase, async: true

  import ExUnit.CaptureLog

  test "a signed-in request's log lines carry the user's id, not the email", %{conn: conn} do
    user = register_user!(email: "private@example.com")

    log =
      capture_log([format: "$metadata$message\n", metadata: [:user_id]], fn ->
        conn |> log_in_user(user) |> get(~p"/account")
      end)

    assert log =~ "user_id=#{user.id} Sent 200"
    refute log =~ "private@example.com"
  end

  test "an action run from a LiveView event carries the view, event and user", %{conn: conn} do
    user = register_user!()

    log =
      capture_log([format: "$metadata$message\n", metadata: [:user_id, :live_view, :event]], fn ->
        conn
        |> log_in_user(user)
        |> visit(~p"/tile-markers/new")
        |> fill_in("Title", with: "Logged tiles")
        |> fill_in("Import string", with: tile_marker_token())
        |> click_button("Save preset")
        |> assert_has("h1", text: "Logged tiles")
      end)

    assert log =~
             "user_id=#{user.id} live_view=RuneshareWeb.PresetLive.Form event=save " <>
               "Sharing.Preset.share ok"
  end

  test "a failed Google callback logs a warning without the callback's parameters",
       %{conn: conn} do
    log =
      capture_log(fn ->
        conn
        |> init_test_session(%{})
        |> get("/auth/user/google/callback?code=leaky-code&state=leaky-state")
        |> redirected_to()
      end)

    assert log =~ "[warning] sign-in failed via {:google, :callback}"
    refute log =~ "leaky"
  end
end
