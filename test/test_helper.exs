{:ok, _} = PhoenixTest.Playwright.Supervisor.start_link()
Application.put_env(:phoenix_test, :base_url, RuneshareWeb.Endpoint.url())

AshStorage.Service.Test.start()

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Runeshare.Repo, :manual)
