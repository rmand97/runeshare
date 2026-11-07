defmodule RuneshareWeb.Plugs.ContentSecurityPolicy do
  @moduledoc """
  Sets a `content-security-policy` header and a fresh per-request nonce in
  `conn.assigns.csp_nonce`. Scripts run only from our own origin or with that
  nonce (the root layout's theme script). Styles allow inline attributes, which
  LiveView, LiveSelect and toasts set. Images may come from any HTTPS host
  (Google avatars, the cover image bucket) plus `data:`/`blob:` for upload
  previews. Nobody may frame the site.
  """

  @behaviour Plug

  import Plug.Conn

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    nonce = 18 |> :crypto.strong_rand_bytes() |> Base.encode64()

    conn
    |> assign(:csp_nonce, nonce)
    |> put_resp_header("content-security-policy", policy(nonce))
  end

  @spec policy(String.t()) :: String.t()
  def policy(nonce) do
    Enum.join(
      [
        "default-src 'self'",
        "script-src 'self' 'nonce-#{nonce}'",
        "style-src 'self' 'unsafe-inline'",
        "img-src 'self' data: blob: https:",
        "font-src 'self' data:",
        "connect-src 'self'",
        "frame-src 'self'",
        "frame-ancestors 'none'",
        "base-uri 'self'",
        "form-action 'self'",
        "object-src 'none'"
      ],
      "; "
    )
  end
end
