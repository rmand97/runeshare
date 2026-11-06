import Config

config :runeshare, token_signing_secret: "cuKwb2IAJIjBuoxCdtST3FBCLDZKzyvN"

config :ash,
  policies: [show_policy_breakdowns?: true],
  keyset_signing_secret: "VXe4A7OfG2L/vNuOJiYF/r2BZ3C3v1z1F920zF/xLWs",
  disable_async?: true

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :runeshare, Runeshare.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  # Slot worktrees override this in config/runtime.exs (runeshare_test_1, ...).
  database: "runeshare_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

config :runeshare, sql_sandbox: true
config :runeshare, :admin_emails, ["admin@example.com"]

# Cover images go to an in-memory store (started in test_helper.exs).
config :runeshare, Runeshare.Sharing.Preset, storage: [service: {AshStorage.Service.Test, []}]

config :runeshare, :google_oauth,
  client_id: "test-google-client-id",
  client_secret: "test-google-client-secret"

config :runeshare, RuneshareWeb.Endpoint,
  # Port is decided in config/runtime.exs from RUNESHARE_SLOT — see `mix runeshare.slot`.
  http: [ip: {127, 0, 0, 1}, port: 4040],
  secret_key_base: "XLc8Tx3+0nl8KXYW5vzZWtdyMsWjOVj4zIma17/6V8jSFAH9SLvQOwMznbZ9It+x",
  # Real server so PhoenixTest.Playwright browser tests can reach the app.
  server: true

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true

# PhoenixTest (feature tests) + PhoenixTest.Playwright (browser tests).
config :phoenix_test,
  endpoint: RuneshareWeb.Endpoint,
  otp_app: :runeshare,
  playwright: [
    screenshot: System.get_env("PW_SCREENSHOT", "false") in ~w(t true),
    trace: System.get_env("PW_TRACE", "false") in ~w(t true)
  ]
