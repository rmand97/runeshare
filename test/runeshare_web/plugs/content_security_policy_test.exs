defmodule RuneshareWeb.Plugs.ContentSecurityPolicyTest do
  use RuneshareWeb.ConnCase, async: true

  test "pages send a CSP whose nonce is on the inline theme script, fresh per request", %{
    conn: conn
  } do
    conn = get(conn, ~p"/")
    [csp] = get_resp_header(conn, "content-security-policy")
    [_all, nonce] = Regex.run(~r/'nonce-([^']+)'/, csp)

    assert csp =~ "script-src 'self' 'nonce-"
    assert csp =~ "frame-ancestors 'none'"
    assert csp =~ "object-src 'none'"
    assert html_response(conn, 200) =~ ~s(<script nonce="#{nonce}">)

    [again] = build_conn() |> get(~p"/") |> get_resp_header("content-security-policy")
    refute again =~ nonce
  end
end
