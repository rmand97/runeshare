defmodule RuneshareWeb.Plugs.CanonicalHost do
  @moduledoc """
  Permanently redirects requests for any other host (e.g. `www.runeshare.dk`,
  `runeshare.fly.dev`) to the canonical one, keeping path and query. The host
  comes from `config :runeshare, :canonical_host` (set from `PHX_HOST` in
  production); without it the plug does nothing.
  """

  @behaviour Plug

  import Plug.Conn

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    case Application.get_env(:runeshare, :canonical_host) do
      host when host in [nil, ""] -> conn
      host when host == conn.host -> conn
      host -> redirect_to(conn, host)
    end
  end

  defp redirect_to(conn, host) do
    query = if conn.query_string == "", do: "", else: "?" <> conn.query_string

    conn
    |> put_resp_header("location", "https://#{host}#{conn.request_path}#{query}")
    |> send_resp(301, "")
    |> halt()
  end
end
