defmodule RuneshareWeb.SeoTest do
  use RuneshareWeb.ConnCase, async: true

  alias Runeshare.Sharing

  defp hidden_preset! do
    preset = share_preset!(register_user!(), %{title: "Secret alarm"})
    Sharing.hide_preset!(preset, actor: register_admin!())
  end

  describe "robots.txt" do
    test "allows crawling, keeps private pages out and points at the sitemap", %{conn: conn} do
      body = conn |> get(~p"/robots.txt") |> response(200)

      assert body =~ "User-agent: *"
      assert body =~ "Disallow: /account"
      assert body =~ "Sitemap: #{url(~p"/sitemap.xml")}"
      refute body =~ "Disallow: /\n"
    end
  end

  describe "sitemap.xml" do
    test "lists the listings, visible presets and their authors, but not hidden ones", %{
      conn: conn
    } do
      author = register_user!()
      preset = share_preset!(author)
      hidden = hidden_preset!()

      conn = get(conn, ~p"/sitemap.xml")
      body = response(conn, 200)

      assert response_content_type(conn, :xml) =~ "application/xml"
      assert body =~ "<loc>#{url(~p"/watchdog")}</loc>"
      assert body =~ "<loc>#{url(~p"/tile-markers")}</loc>"
      assert body =~ "<loc>#{url(~p"/presets/#{preset}")}</loc><lastmod>"
      assert body =~ "<loc>#{url(~p"/u/#{author}")}</loc>"
      refute body =~ hidden.id
      refute body =~ hidden.author_id
    end
  end

  describe "page meta" do
    test "a preset page is canonical and describes the preset", %{conn: conn} do
      preset = share_preset!(register_user!(), %{title: "Vorago rotation"})
      html = conn |> get(~p"/presets/#{preset}") |> html_response(200)

      assert html =~ ~s(<link rel="canonical" href="#{url(~p"/presets/#{preset}")}")
      assert html =~ ~s(<meta property="og:type" content="article")
      assert html =~ "Vorago rotation — RS3 Watchdog alarm"
      refute html =~ ~s(name="robots")
    end

    test "an older version points its canonical at the preset", %{conn: conn} do
      author = register_user!()
      preset = share_preset!(author)
      Sharing.edit_preset!(preset, %{title: "Renamed"}, actor: author)

      html = conn |> get(~p"/presets/#{preset}/v/1") |> html_response(200)

      assert html =~ ~s(<link rel="canonical" href="#{url(~p"/presets/#{preset}")}")
    end

    test "a hidden preset is not indexed", %{conn: conn} do
      preset = hidden_preset!()

      html =
        conn
        |> log_in_user(register_admin!())
        |> get(~p"/presets/#{preset}")
        |> html_response(200)

      assert html =~ ~s(<meta name="robots" content="noindex")
      refute html =~ ~s(rel="canonical")
    end

    test "a tag listing is its own canonical page; sort and paging variants are not",
         %{conn: conn} do
      html = conn |> get(~p"/watchdog?tag=vorago&sort=most_liked") |> html_response(200)

      assert html =~ ~s(<link rel="canonical" href="#{url(~p"/watchdog?tag=vorago")}")
      assert html =~ ">vorago Watchdog alarms · RuneShare</title>"
    end

    test "search results are not indexed", %{conn: conn} do
      html = conn |> get(~p"/watchdog?q=vorago") |> html_response(200)

      assert html =~ ~s(<meta name="robots" content="noindex")
    end

    test "pages behind sign-in and the sign-in page are not indexed", %{conn: conn} do
      account = conn |> log_in_user(register_user!()) |> get(~p"/account") |> html_response(200)
      sign_in = build_conn() |> get(~p"/sign-in") |> html_response(200)

      assert account =~ ~s(<meta name="robots" content="noindex")
      assert sign_in =~ ~s(<meta name="robots" content="noindex")
    end

    test "the home page is canonical with a descriptive title", %{conn: conn} do
      html = conn |> get(~p"/") |> html_response(200)

      assert html =~ ~s(<link rel="canonical" href="#{url(~p"/")}")
      assert html =~ "RS3 Watchdog alarms &amp; tile markers · RuneShare"
    end
  end
end
