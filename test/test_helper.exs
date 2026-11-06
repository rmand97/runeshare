# Browser tests need Node + Playwright; CI skips them with `--exclude playwright`.
unless :playwright in Keyword.get(ExUnit.configuration(), :exclude, []) do
  {:ok, _} = PhoenixTest.Playwright.Supervisor.start_link()
end

Application.put_env(:phoenix_test, :base_url, RuneshareWeb.Endpoint.url())

AshStorage.Service.Test.start()

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Runeshare.Repo, :manual)
