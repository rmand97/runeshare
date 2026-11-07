defmodule RuneshareWeb.InjectionTest do
  @moduledoc false
  # Whatever people type is stored as-is and shown as text: HEEx escapes it on
  # output and Ecto sends it to Postgres as a parameter. These tests put attack
  # strings everywhere users can write and check they never come back live.
  use RuneshareWeb.ConnCase, async: true

  import Phoenix.LiveViewTest, only: [live: 2, render_async: 2]

  alias Runeshare.Accounts
  alias Runeshare.Sharing

  @script "<script>alert('xss')</script>"
  @img "<img src=x onerror=\"alert('xss')\">"
  @attr "\" onmouseover=\"alert('xss')"
  @payloads [@script, @img, @attr]

  # Live markup an injection would produce; escaped text never contains these.
  @live ["<script>alert", "<img src=x", "onerror=\"alert", "\" onmouseover=\"", "<i>x</i>"]

  defp refute_injected(html) do
    for live <- @live, do: refute(html =~ live, "found live markup #{inspect(live)}")
    html
  end

  # A Watchdog export whose alert name tries to close the page's <script> blocks.
  defp hostile_export do
    "#{@script}</script><script>alert(1)</script>"
    |> watchdog_export()
  end

  setup do
    author = register_user!()
    author = Accounts.update_profile!(author, %{name: "Eve #{@attr}"}, actor: author)

    preset =
      share_preset!(author, %{
        title: "Boss #{@script}",
        description: "Read me #{@img} #{@attr}",
        # Tags are at most 24 characters.
        tags: ["vorago", "<i>x</i>"],
        content: hostile_export()
      })

    Sharing.post_comment!(preset.id, "Nice #{@script} #{@img}", actor: register_user!())

    %{author: author, preset: preset}
  end

  test "the preset page shows every field as text, including meta tags and JSON-LD", %{
    conn: conn,
    preset: preset
  } do
    html = conn |> get(~p"/presets/#{preset}") |> html_response(200) |> refute_injected()

    assert html =~ "Boss &lt;script&gt;alert(&#39;xss&#39;)&lt;/script&gt;"
    # The page's own scripts are only the theme script and app.js (+ the JSON-LD data).
    assert Enum.count(Regex.scan(~r/<script[\s>]/, html)) == 3
  end

  test "listings, the front page, the author page and comments escape it too", %{
    conn: conn,
    author: author,
    preset: preset
  } do
    for {path, shown} <- [
          {~p"/watchdog", "Boss &lt;script&gt;"},
          {~p"/", "Boss &lt;script&gt;"},
          {~p"/u/#{author}", "Boss &lt;script&gt;"},
          {~p"/presets/#{preset}", "Nice &lt;script&gt;"}
        ] do
      conn |> live_html(path, shown) |> refute_injected()
    end
  end

  # The LiveView's HTML once its async lists have loaded `shown`. Shares from
  # tests running alongside can restart a list's load, so render until it's there.
  defp live_html(conn, path, shown, tries \\ 20) do
    {:ok, view, _html} = live(conn, path)
    await(view, shown, tries)
  end

  defp await(view, shown, tries) do
    html = render_async(view, 2_000)
    if html =~ shown or tries == 0, do: html, else: await(view, shown, tries - 1)
  end

  test "values are stored exactly as typed, not mangled", %{preset: preset} do
    stored = Sharing.get_preset!(preset.id)

    assert stored.title == "Boss #{@script}"
    assert stored.description =~ @img
    assert stored.content == hostile_export()
  end

  describe "SQL injection" do
    for {param, value} <- [
          q: "' OR 1=1 --",
          q: "%'; DROP TABLE presets; --",
          tag: "x'); DROP TABLE presets; --",
          sort: "title; DROP TABLE presets",
          offset: "0; DROP TABLE presets",
          per: "1 OR 1=1"
        ] do
      test "#{param}=#{value} is just a value", %{conn: conn, preset: preset} do
        query = URI.encode_query(%{unquote(param) => unquote(value)})
        html = conn |> get("/watchdog?#{query}") |> html_response(200)

        assert html =~ "Watchdog alarms"
        # The table is still there and still holds the preset.
        assert {:ok, _} = Sharing.get_preset(preset.id)
      end
    end

    test "search treats quotes and wildcards literally", %{preset: preset} do
      assert %{results: []} =
               Sharing.list_presets!(:watchdog_alarm, %{search: "' OR '1'='1"}, page: [limit: 10])

      assert %{results: [%{id: id}]} =
               Sharing.list_presets!(:watchdog_alarm, %{search: "<script>"}, page: [limit: 10])

      assert id == preset.id
    end
  end

  describe "payload coverage" do
    test "every payload is one users could actually save" do
      for payload <- @payloads do
        assert {:ok, _} =
                 Sharing.post_comment(share_preset!(register_user!()).id, payload,
                   actor: register_user!()
                 )
      end
    end
  end
end
