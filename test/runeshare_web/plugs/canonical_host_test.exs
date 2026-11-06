defmodule RuneshareWeb.Plugs.CanonicalHostTest do
  # Not async: sets the global canonical host.
  use RuneshareWeb.ConnCase, async: false

  alias RuneshareWeb.Plugs.CanonicalHost

  setup do
    Application.put_env(:runeshare, :canonical_host, "runeshare.dk")
    on_exit(fn -> Application.delete_env(:runeshare, :canonical_host) end)
  end

  test "other hosts redirect permanently to the canonical one, keeping path and query" do
    conn =
      build_conn(:get, "https://www.runeshare.dk/watchdog?tag=vorago")
      |> CanonicalHost.call([])

    assert conn.halted
    assert conn.status == 301
    assert get_resp_header(conn, "location") == ["https://runeshare.dk/watchdog?tag=vorago"]
  end

  test "the canonical host passes through" do
    conn = build_conn(:get, "https://runeshare.dk/watchdog") |> CanonicalHost.call([])

    refute conn.halted
  end
end
