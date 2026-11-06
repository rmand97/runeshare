defmodule RuneshareWeb.Plugs.VisitorId do
  @moduledoc """
  Gives every browser session a random `"visitor_id"`, so anonymous visitors can
  be told apart (e.g. one counted copy per visitor) without storing anything
  about them.
  """

  @behaviour Plug

  import Plug.Conn

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    if get_session(conn, "visitor_id"),
      do: conn,
      else: put_session(conn, "visitor_id", Ash.UUID.generate())
  end
end
