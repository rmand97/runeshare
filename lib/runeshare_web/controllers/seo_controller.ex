defmodule RuneshareWeb.SeoController do
  @moduledoc """
  `robots.txt` and `sitemap.xml`. Both are built per request so their absolute
  URLs follow the endpoint's configured host.
  """

  use RuneshareWeb, :controller

  import RuneshareWeb.PresetComponents, only: [kind_path: 1]

  alias Runeshare.Sharing

  # Pages a crawler gains nothing from: sign-in, private and moderation pages, forms.
  @disallowed ~w(/auth/ /sign-in /sign-out /account /moderation /watchdog/new /tile-markers/new /presets/*/edit /dev/ /admin/)

  @spec robots(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def robots(conn, _params) do
    body =
      Enum.join(
        ["User-agent: *"] ++
          Enum.map(@disallowed, &"Disallow: #{&1}") ++
          ["", "Sitemap: #{url(~p"/sitemap.xml")}", ""],
        "\n"
      )

    conn |> put_resp_content_type("text/plain") |> send_resp(200, body)
  end

  # Served as application/xml, and every URL in it is escaped by `sitemap_xml/1`.
  @spec sitemap(Plug.Conn.t(), map()) :: Plug.Conn.t()
  # sobelow_skip ["XSS.SendResp"]
  def sitemap(conn, _params) do
    # Anonymous read: hidden presets stay out.
    presets = Sharing.list_sitemap_presets!()

    entries =
      [{url(~p"/"), nil}] ++
        Enum.map(
          Sharing.preset_kinds(),
          &{unverified_url(RuneshareWeb.Endpoint, kind_path(&1)), nil}
        ) ++
        Enum.map(presets, &{url(~p"/presets/#{&1}"), &1.updated_at}) ++
        author_entries(presets)

    conn
    |> put_resp_content_type("application/xml")
    |> send_resp(200, sitemap_xml(entries))
  end

  # One entry per author, dated by their newest visible share (presets come newest first).
  defp author_entries(presets) do
    presets
    |> Enum.uniq_by(& &1.author_id)
    |> Enum.map(&{url(~p"/u/#{&1.author_id}"), &1.updated_at})
  end

  defp lastmod(nil), do: []
  defp lastmod(at), do: ["<lastmod>", at |> DateTime.to_date() |> Date.to_iso8601(), "</lastmod>"]

  defp sitemap_xml(entries) do
    urls =
      Enum.map(entries, fn {loc, lastmod} ->
        [
          "  <url><loc>",
          Plug.HTML.html_escape(loc),
          "</loc>",
          lastmod(lastmod),
          "</url>\n"
        ]
      end)

    IO.iodata_to_binary([
      ~s(<?xml version="1.0" encoding="UTF-8"?>\n),
      ~s(<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n),
      urls,
      "</urlset>\n"
    ])
  end
end
