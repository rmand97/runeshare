defmodule RuneshareWeb.ConnCase do
  @moduledoc """
  Test case for anything that needs a connection: controllers and LiveViews,
  driven through PhoenixTest.
  """

  use ExUnit.CaseTemplate

  alias AshAuthentication.Plug.Helpers, as: AuthHelpers
  alias Phoenix.Ecto.SQL.Sandbox

  using do
    quote do
      @endpoint RuneshareWeb.Endpoint

      use RuneshareWeb, :verified_routes

      import Phoenix.ConnTest
      import PhoenixTest
      import Plug.Conn
      import Runeshare.Test.Builders
      import RuneshareWeb.ConnCase
    end
  end

  setup tags do
    pid = Runeshare.DataCase.setup_sandbox(tags)

    conn =
      Phoenix.ConnTest.build_conn()
      |> Plug.Conn.put_req_header(
        "user-agent",
        Sandbox.encode_metadata(Sandbox.metadata_for(Runeshare.Repo, pid))
      )

    {:ok, conn: conn}
  end

  @doc "Signs `user` into `conn`'s session."
  @spec log_in_user(Plug.Conn.t(), Runeshare.Accounts.User.t()) :: Plug.Conn.t()
  def log_in_user(conn, user) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> AuthHelpers.store_in_session(user)
  end
end
