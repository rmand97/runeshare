defmodule RuneshareWeb.ModerationLiveTest do
  use RuneshareWeb.ConnCase, async: true

  alias Runeshare.Sharing

  setup do
    preset = share_preset!(register_user!(name: "Spammer"), %{title: "Gold for sale"})
    reporter = register_user!(name: "Reporter")
    Sharing.report_preset!(preset.id, :spam, %{note: "Selling gold"}, actor: reporter)
    %{preset: preset, admin: register_admin!()}
  end

  test "non-admins are redirected away", %{conn: conn} do
    conn
    |> log_in_user(register_user!())
    |> visit(~p"/moderation")
    |> assert_path(~p"/")
    |> assert_has("#flash-error", text: "Only moderators")
  end

  test "signed-out visitors are sent to sign in", %{conn: conn} do
    conn
    |> visit(~p"/moderation")
    |> assert_path(~p"/sign-in")
  end

  test "admins see open reports with reason and note", %{conn: conn, admin: admin} do
    conn
    |> log_in_user(admin)
    |> visit(~p"/moderation")
    |> assert_has("#reports-list a", text: "Gold for sale", timeout: 2_000)
    |> assert_has("#reports-list", text: "Spam")
    |> assert_has("#reports-list", text: "Selling gold")
    |> assert_has("#reports-list a", text: "Spammer")
    |> assert_has("#reports-list a", text: "Reporter")
  end

  test "resolving dismisses the report", %{conn: conn, admin: admin} do
    conn
    |> log_in_user(admin)
    |> visit(~p"/moderation")
    |> assert_has("#reports-list a", text: "Gold for sale", timeout: 2_000)
    |> click_button("Resolve")
    |> refute_has("#reports-list a", text: "Gold for sale")
    |> assert_has("#reports-list", text: "No open reports.")

    assert Enum.empty?(Sharing.list_open_reports!(actor: admin))
  end

  test "hiding the preset hides it and resolves the report", %{
    conn: conn,
    admin: admin,
    preset: preset
  } do
    conn
    |> log_in_user(admin)
    |> visit(~p"/moderation")
    |> assert_has("#reports-list a", text: "Gold for sale", timeout: 2_000)
    |> click_button("Hide preset")
    |> refute_has("#reports-list a", text: "Gold for sale")

    assert Sharing.get_preset!(preset.id, actor: admin).hidden
    assert Enum.empty?(Sharing.list_open_reports!(actor: admin))
  end

  test "deleting the preset removes it and its report", %{
    conn: conn,
    admin: admin,
    preset: preset
  } do
    conn
    |> log_in_user(admin)
    |> visit(~p"/moderation")
    |> assert_has("#reports-list a", text: "Gold for sale", timeout: 2_000)
    |> click_button("Delete preset")
    |> refute_has("#reports-list a", text: "Gold for sale")

    assert_raise Ash.Error.Invalid, fn -> Sharing.get_preset!(preset.id, actor: admin) end
  end

  describe "navigation" do
    test "shows Moderation to admins", %{conn: conn, admin: admin} do
      conn
      |> log_in_user(admin)
      |> visit(~p"/")
      |> assert_has("header a", text: "Moderation")
    end

    test "hides Moderation from everyone else", %{conn: conn} do
      conn
      |> log_in_user(register_user!())
      |> visit(~p"/")
      |> refute_has("header a", text: "Moderation")
    end
  end
end
