defmodule RuneshareWeb.BrowserHelpers do
  @moduledoc """
  Helpers for `PhoenixTest.Playwright.Case` browser tests.
  """

  import PhoenixTest.Playwright, only: [add_session_cookie: 3]

  alias AshAuthentication.Plug.Helpers, as: AuthHelpers

  @doc "Signs `user` into the Playwright browser context."
  @spec log_in_user(PhoenixTest.Playwright.t(), Runeshare.Accounts.User.t()) ::
          PhoenixTest.Playwright.t()
  def log_in_user(conn, user) do
    session =
      Phoenix.ConnTest.build_conn()
      |> Plug.Test.init_test_session(%{})
      |> AuthHelpers.store_in_session(user)
      |> Plug.Conn.get_session()

    add_session_cookie(
      conn,
      [value: session, url: Application.fetch_env!(:phoenix_test, :base_url)],
      RuneshareWeb.Endpoint.session_options()
    )
  end
end
