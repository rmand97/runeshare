defmodule RuneshareWeb.PresetShowTest do
  use RuneshareWeb.ConnCase, async: true

  import Phoenix.LiveViewTest, only: [live: 2, render_hook: 3, assert_redirect: 2]

  alias Runeshare.Sharing

  describe "preset page" do
    test "a preset page shows the import string", %{conn: conn} do
      preset = share_preset!(register_user!(), %{content: watchdog_export("Vorago rotation")})

      conn
      |> visit(~p"/presets/#{preset}")
      |> assert_has("#preset-content", text: "schemaVersion")
      |> assert_has("#preset-alerts li", text: "Vorago rotation")
      |> refute_has("button", text: "Delete")
    end

    test "the author can delete their preset", %{conn: conn} do
      author = register_user!()
      preset = share_preset!(author, %{title: "Doomed alarm"})

      conn
      |> log_in_user(author)
      |> visit(~p"/presets/#{preset}")
      |> click_button("Delete")
      |> assert_path(~p"/watchdog")
      |> refute_has("a", text: "Doomed alarm")
    end
  end

  describe "versions list" do
    test "shows the newest three and the one on screen; older ones fold away", %{conn: conn} do
      author = register_user!()
      preset = share_preset!(author)

      Enum.reduce(2..6, preset, fn n, preset ->
        Sharing.edit_preset!(preset, %{title: "Version #{n}"}, actor: author)
      end)

      conn
      |> visit(~p"/presets/#{preset}/v/1")
      |> assert_has("#versions li", count: 4, timeout: 2_000)
      |> assert_has("#versions #version-1")
      |> assert_has("#older-versions summary", text: "Show 2 older versions")
      |> assert_has("#older-versions #version-3")
    end
  end

  describe "versions" do
    setup do
      author = register_user!()
      preset = share_preset!(author, %{content: watchdog_export("Old alert")})

      preset =
        Sharing.edit_preset!(preset, %{content: watchdog_export("New alert")}, actor: author)

      %{author: author, preset: preset}
    end

    test "the latest version shows its number and every version", %{conn: conn, preset: preset} do
      conn
      |> visit(~p"/presets/#{preset}")
      |> assert_has("#version-badge", text: "v2")
      |> assert_has("#preset-alerts li", text: "New alert")
      |> assert_has("#versions li", text: "v2", timeout: 2_000)
      |> assert_has("#versions li", text: "v1")
      |> refute_has("#version-banner")
    end

    test "an older version shows its content and points to the latest", %{
      conn: conn,
      author: author,
      preset: preset
    } do
      conn
      |> log_in_user(author)
      |> visit(~p"/presets/#{preset}/v/1")
      |> assert_has("#preset-alerts li", text: "Old alert")
      |> assert_has("#version-banner", text: "A newer version (v2) is available")
      |> refute_has("button", text: "Delete")
      |> click_link("View latest")
      |> assert_path(~p"/presets/#{preset}")
      |> assert_has("#preset-alerts li", text: "New alert")
    end

    test "the current version's number leads to the preset page", %{conn: conn, preset: preset} do
      conn
      |> visit(~p"/presets/#{preset}/v/2")
      |> assert_path(~p"/presets/#{preset}")
      |> refute_has("#version-banner")
    end
  end

  describe "likes" do
    test "a signed-in user likes a preset", %{conn: conn} do
      preset = share_preset!(register_user!())

      conn
      |> log_in_user(register_user!())
      |> visit(~p"/presets/#{preset}")
      |> assert_has("#like-button", text: "0")
      |> click_button("#like-button", "Like")
      |> assert_has("#like-button", text: "Liked")
      |> assert_has("#like-button", text: "1")
    end

    test "unliking a like already removed in another tab doesn't crash the page", %{conn: conn} do
      preset = share_preset!(register_user!())
      fan = register_user!()
      Sharing.like_preset!(preset.id, actor: fan)

      session =
        conn
        |> log_in_user(fan)
        |> visit(~p"/presets/#{preset}")
        |> assert_has("#like-button", text: "Liked")

      # Removed elsewhere, and this page hasn't heard about it yet.
      Sharing.unlike_preset!(preset.id, fan.id, actor: fan, return_notifications?: true)

      session
      |> click_button("#like-button", "Liked")
      |> assert_has("#like-button", text: "0")
    end
  end

  describe "comments" do
    test "a long thread shows the latest 20; earlier ones load on request, oldest on top", %{
      conn: conn
    } do
      preset = share_preset!(register_user!())
      # Three commenters: the comment rate limit is 10 per user per 5 minutes.
      commenters = for _ <- 1..3, do: register_user!()

      for n <- 1..25 do
        Sharing.post_comment!(preset.id, "Comment #{n}", actor: Enum.at(commenters, rem(n, 3)))
      end

      conn
      |> visit(~p"/presets/#{preset}")
      |> assert_has("#comments li", text: "Comment 25", timeout: 2_000)
      |> assert_has("#comments li[data-phx-stream]", count: 20)
      |> refute_has("#comments li", text: "Comment 5", exact: true)
      |> assert_has("#more-comments", text: "Show earlier comments (5 more)")
      |> click_button("#more-comments", "Show earlier comments")
      |> assert_has("#comments li[data-phx-stream]", count: 25, timeout: 2_000)
      |> assert_has("#comments li[data-phx-stream]:first-child", text: "Comment 1")
      |> refute_has("#more-comments")
    end

    test "a signed-in user posts a comment", %{conn: conn} do
      preset = share_preset!(register_user!())

      conn
      |> log_in_user(register_user!(name: "Zezima"))
      |> visit(~p"/presets/#{preset}")
      |> fill_in("Add a comment", with: "Works great at Vorago")
      |> click_button("Post comment")
      |> assert_has("#comments li", text: "Works great at Vorago")
      |> assert_has("#comments li", text: "Zezima")
      |> assert_has("#preset-comments h2", text: "Comments (1)")
    end

    test "a signed-out visitor is asked to sign in", %{conn: conn} do
      preset = share_preset!(register_user!())

      conn
      |> visit(~p"/presets/#{preset}")
      |> assert_has("a", text: "Sign in to comment")
      |> refute_has("#comment-form")
    end

    test "the preset author deletes someone's comment; strangers cannot", %{conn: conn} do
      author = register_user!()
      preset = share_preset!(author)
      Sharing.post_comment!(preset.id, "Spam spam spam", actor: register_user!())

      conn
      |> log_in_user(register_user!())
      |> visit(~p"/presets/#{preset}")
      |> assert_has("#comments li", text: "Spam spam spam", timeout: 2_000)
      |> refute_has("#comments button", text: "Delete comment")

      build_conn()
      |> log_in_user(author)
      |> visit(~p"/presets/#{preset}")
      |> assert_has("#comments li", text: "Spam spam spam", timeout: 2_000)
      |> click_button("#comments button", "Delete comment")
      |> refute_has("#comments li", text: "Spam spam spam")
    end
  end

  describe "link previews" do
    test "the preset page carries OpenGraph tags", %{conn: conn} do
      preset = share_preset!(register_user!(), %{title: "Vorago rotation timer"})
      head = conn |> get(~p"/presets/#{preset}") |> html_response(200) |> LazyHTML.from_document()

      assert meta(head, "meta[property='og:title']") ==
               "Vorago rotation timer — RS3 Watchdog alarm"

      assert meta(head, "meta[property='og:description']") == "Pings before each rotation."
      assert meta(head, "meta[property='og:url']") =~ ~r"^http.*/presets/#{preset.id}$"
      assert meta(head, "meta[name='twitter:card']") == "summary"
    end

    test "pages without their own tags fall back to site defaults", %{conn: conn} do
      head = conn |> get(~p"/sign-in") |> html_response(200) |> LazyHTML.from_document()

      assert meta(head, "meta[property='og:title']") == "RuneShare"
      assert meta(head, "meta[property='og:site_name']") == "RuneShare"
    end
  end

  describe "details" do
    test "shows tags linking to the filtered listing and the copy count", %{conn: conn} do
      preset = share_preset!(register_user!(), %{tags: ["vorago"]})

      conn
      |> visit(~p"/presets/#{preset}")
      |> assert_has("#preset-tags a[href='/watchdog?tag=vorago']", text: "vorago")
      |> assert_has("#copy-count", text: "Copied 0×")
    end

    test "a copy is counted once per visitor, even across page reloads", %{conn: conn} do
      preset = share_preset!(register_user!())
      conn = get(conn, ~p"/presets/#{preset}")

      for _visit <- 1..2 do
        {:ok, view, _html} = live(conn, ~p"/presets/#{preset}")
        render_hook(view, "copied", %{"id" => preset.id})
        assert render_hook(view, "copied", %{"id" => preset.id}) =~ "Copied 1×"
      end

      {:ok, view, _html} = live(build_conn(), ~p"/presets/#{preset}")
      assert render_hook(view, "copied", %{"id" => preset.id}) =~ "Copied 2×"
    end

    test "a Watchdog export is summarised per alert", %{conn: conn} do
      export =
        JSON.encode!(%{
          "schemaVersion" => 1,
          "entries" => [
            %{
              "name" => "Mining fatigue",
              "graph" => %{
                "nodes" => [
                  %{"type" => "trigger.xp_drop"},
                  %{"type" => "action.sound"},
                  %{"type" => "action.screen_flash"}
                ]
              }
            }
          ]
        })

      preset = share_preset!(register_user!(), %{content: export})

      conn
      |> visit(~p"/presets/#{preset}")
      |> assert_has("#preset-alerts li", text: "Mining fatigue")
      |> assert_has("#preset-alerts dd", text: "XP drop")
      |> assert_has("#preset-alerts dd", text: "Sound, Screen flash")
    end
  end

  describe "version notes" do
    test "each version shows its note", %{conn: conn} do
      author = register_user!()
      preset = share_preset!(author)

      Sharing.edit_preset!(preset, %{title: "Vorago v2", change_note: "Faster ping"},
        actor: author
      )

      conn
      |> visit(~p"/presets/#{preset}")
      |> assert_has("#versions li", text: "Faster ping", timeout: 2_000)
    end

    test "a comment from an older version links to it", %{conn: conn} do
      author = register_user!()
      preset = share_preset!(author)
      Sharing.post_comment!(preset.id, "Nice one", actor: register_user!())
      Sharing.edit_preset!(preset, %{title: "Vorago v2"}, actor: author)

      conn
      |> visit(~p"/presets/#{preset}")
      |> assert_has("#comments li a[href='/presets/#{preset.id}/v/1']",
        text: "on v1",
        timeout: 2_000
      )
    end
  end

  describe "reports" do
    test "a signed-in user reports a preset", %{conn: conn} do
      preset = share_preset!(register_user!())

      conn
      |> log_in_user(register_user!())
      |> visit(~p"/presets/#{preset}")
      |> click_button("Report")
      |> select("Reason", option: "Spam")
      |> fill_in("Note (optional)", with: "Links to a gold site")
      |> click_button("Send report")
      |> assert_has("#toast-group [role=alert]",
        text: "Thanks — a moderator will take a look.",
        timeout: 1_000
      )
      |> refute_has("#report-form")
    end

    test "signed-out visitors and the author see no report button", %{conn: conn} do
      author = register_user!()
      preset = share_preset!(author)

      conn
      |> visit(~p"/presets/#{preset}")
      |> refute_has("button", text: "Report")

      build_conn()
      |> log_in_user(author)
      |> visit(~p"/presets/#{preset}")
      |> refute_has("button", text: "Report")
    end
  end

  describe "moderation" do
    test "an admin hides a preset; visitors then can't open it", %{conn: conn} do
      preset = share_preset!(register_user!())

      conn
      |> log_in_user(register_admin!())
      |> visit(~p"/presets/#{preset}")
      |> click_button("#toggle-hidden", "Hide")
      |> assert_has("#hidden-banner", text: "Hidden by a moderator")
      |> assert_has("#toggle-hidden", text: "Unhide")

      assert_raise Ash.Error.Invalid, fn -> visit(build_conn(), ~p"/presets/#{preset}") end
    end

    test "a visitor watching a preset is sent away when it is hidden", %{conn: conn} do
      preset = share_preset!(register_user!())
      {:ok, view, _html} = live(conn, ~p"/presets/#{preset}")

      Sharing.hide_preset!(preset, actor: register_admin!())

      {path, flash} = assert_redirect(view, 1_000)
      assert path == ~p"/watchdog"
      assert flash["error"] == "This preset was removed by a moderator."
    end

    test "an admin deletes someone else's comment", %{conn: conn} do
      preset = share_preset!(register_user!())
      Sharing.post_comment!(preset.id, "Spam spam spam", actor: register_user!())

      conn
      |> log_in_user(register_admin!())
      |> visit(~p"/presets/#{preset}")
      |> assert_has("#comments li", text: "Spam spam spam", timeout: 2_000)
      |> click_button("#comments button", "Delete comment")
      |> refute_has("#comments li", text: "Spam spam spam")
    end
  end

  defp meta(document, selector) do
    [content] = document |> LazyHTML.query(selector) |> LazyHTML.attribute("content")
    content
  end
end
