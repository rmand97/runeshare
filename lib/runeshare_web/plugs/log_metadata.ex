defmodule RuneshareWeb.Plugs.LogMetadata do
  @moduledoc """
  Tags the request's log lines with the signed-in user's id (`user_id`), next to
  the `request_id` from `Plug.RequestId`. Never the email. Runs after
  `:load_from_session`; LiveViews get the same from `RuneshareWeb.LiveUserAuth`.
  """

  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    case conn.assigns[:current_user] do
      %{id: id} -> Logger.metadata(user_id: id)
      _anonymous -> :ok
    end

    conn
  end
end
