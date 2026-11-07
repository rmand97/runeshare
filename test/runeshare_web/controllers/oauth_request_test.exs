defmodule RuneshareWeb.OAuthRequestTest do
  use RuneshareWeb.ConnCase, async: true

  alias Plug.Conn.Query

  # Starting a sign-in only builds a redirect, so no provider is called. (Twitch
  # is left out: its OpenID Connect request step fetches Twitch's configuration.)
  for {provider, authorize_url} <- [
        google: "https://accounts.google.com/o/oauth2/v2/auth",
        github: "https://github.com/login/oauth/authorize",
        discord: "https://discord.com/api/oauth2/authorize"
      ] do
    test "the #{provider} button sends the visitor to #{provider} with our client and callback",
         %{conn: conn} do
      provider = unquote(provider)
      conn = get(conn, "/auth/user/#{provider}")

      assert [location] = get_resp_header(conn, "location")
      assert String.starts_with?(location, unquote(authorize_url))

      query = location |> URI.parse() |> Map.fetch!(:query) |> Query.decode()
      assert query["client_id"] == "test-#{provider}-client-id"
      assert query["redirect_uri"] =~ "/auth/user/#{provider}/callback"
    end
  end

  test "Discord asks for the email scope (needed to match accounts)", %{conn: conn} do
    [location] = conn |> get("/auth/user/discord") |> get_resp_header("location")
    assert Query.decode(URI.parse(location).query)["scope"] =~ "email"
  end

  test "the sign-in page offers all four providers, with GitHub spelled right", %{conn: conn} do
    session = visit(conn, ~p"/sign-in")

    for {provider, label} <- [
          google: "Google",
          github: "GitHub",
          discord: "Discord",
          twitch: "Twitch"
        ] do
      assert_has(session, "a[href='/auth/user/#{provider}']", text: "Sign in with #{label}")
    end
  end

  test "sign-in texts still get their %{placeholders} filled in" do
    assert RuneshareWeb.AuthText.translate("Hello %{name}", name: "Zezima") == "Hello Zezima"
  end
end
