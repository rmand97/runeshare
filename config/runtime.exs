import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# Load .env in dev/test. In prod, env vars come from the host.
#
# Dotenvy's default side effect stashes the parsed values in the process
# dictionary, where `System.get_env/1` cannot see them — so the merged map is
# written into the real environment here. Real env vars are listed last and
# therefore win over the file.
if config_env() in [:dev, :test] do
  import Dotenvy

  [".env", ".env.#{config_env()}", System.get_env()]
  |> source!()
  |> System.put_env()
end

# ## Development slots
#
# Several agents work this repo at once from sibling git worktrees (see
# `bin/agent-worktree` and the `parallel-agents` skill). Each checkout owns a
# slot 0..9 from `RUNESHARE_SLOT`, and every port and database name derives
# from it. Slot 0 is the main checkout: port 4000, `runeshare_dev`, `runeshare_test`.
#
# `Runeshare.Slot` holds the same arithmetic for humans and mix tasks. It cannot
# be called here — config is evaluated before `lib/` is compiled — so the
# numbers are inlined. `test/runeshare/slot_test.exs` pins them; keep in step.
if config_env() in [:dev, :test] do
  slot = String.to_integer(System.get_env("RUNESHARE_SLOT", "0"))
  partition = String.to_integer(System.get_env("MIX_TEST_PARTITION", "0"))
  suffix = if slot == 0, do: "", else: "_#{slot}"

  config :runeshare, Runeshare.Repo,
    database: "runeshare_#{config_env()}#{if partition == 0, do: "", else: partition}#{suffix}"

  if config_env() == :test do
    config :runeshare, RuneshareWeb.Endpoint, http: [port: 4040 + slot + 10 * partition]
  else
    # Mix has already consumed System.argv/0 by the time config is evaluated, so
    # the raw VM arguments are what still carry the task name.
    serving? =
      Enum.any?(:init.get_plain_arguments(), &(List.to_string(&1) == "phx.server")) or
        System.get_env("PHX_SERVER") != nil

    # Explicit PORT wins. Otherwise a slot gives a deterministic port, which is
    # what the tidewave/ash_ai MCP URLs in .mcp.json are wired to. With neither
    # set we probe, but only when actually starting a server.
    port =
      cond do
        env_port = System.get_env("PORT") ->
          String.to_integer(env_port)

        slot > 0 ->
          4000 + slot

        serving? ->
          Enum.find(4000..4099, 4000, fn candidate ->
            case :gen_tcp.listen(candidate, [:binary, active: false, reuseaddr: true]) do
              {:ok, socket} ->
                :gen_tcp.close(socket)
                true

              {:error, _reason} ->
                false
            end
          end)

        true ->
          4000
      end

    config :runeshare, RuneshareWeb.Endpoint,
      http: [port: port],
      url: [host: "localhost", port: port]
  end
end

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/runeshare start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :runeshare, RuneshareWeb.Endpoint, server: true
end

# Dev and test ports are decided by the slot block above.
if config_env() == :prod do
  config :runeshare, RuneshareWeb.Endpoint,
    http: [port: String.to_integer(System.get_env("PORT", "4000"))]

  # Cover images live in a public Tigris bucket. `fly storage create --public` sets
  # BUCKET_NAME, AWS_ENDPOINT_URL_S3, AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY.
  # Credentials are read from the environment by name and never stored on blobs.
  bucket = System.get_env("BUCKET_NAME") || raise "environment variable BUCKET_NAME is missing"

  config :runeshare, Runeshare.Sharing.Preset,
    storage: [
      service:
        {AshStorage.Service.S3,
         bucket: bucket,
         region: "auto",
         endpoint_url: System.get_env("AWS_ENDPOINT_URL_S3", "https://t3.storage.dev"),
         prefix: "covers/",
         public_base_url:
           System.get_env("STORAGE_PUBLIC_URL", "https://#{bucket}.t3.tigrisfiles.io")}
    ]
end

# Comma-separated emails that get the admin (moderator) role on sign-in (any provider).
if config_env() in [:dev, :prod] do
  config :runeshare,
         :admin_emails,
         "ADMIN_EMAILS"
         |> System.get_env("")
         |> String.split(",", trim: true)
         |> Enum.map(&(&1 |> String.trim() |> String.downcase()))
end

# OAuth sign-in providers. Test env uses fixed fake values from config/test.exs.
# Each provider's redirect/callback URL is `<base url>/auth/user/<provider>/callback`:
#   Google  https://console.cloud.google.com/apis/credentials
#   GitHub  https://github.com/settings/developers (OAuth App)
#   Discord https://discord.com/developers/applications (OAuth2 > Redirects)
#   Twitch  https://dev.twitch.tv/console/apps
# A provider without credentials still shows its button; signing in with it fails.
if config_env() in [:dev, :prod] do
  for {provider, env} <- [
        google_oauth: "GOOGLE",
        github_oauth: "GITHUB",
        discord_oauth: "DISCORD",
        twitch_oauth: "TWITCH"
      ] do
    config :runeshare, provider,
      client_id: System.get_env("#{env}_CLIENT_ID"),
      client_secret: System.get_env("#{env}_CLIENT_SECRET"),
      redirect_uri: System.get_env("#{env}_REDIRECT_URI")
  end
end

if config_env() == :dev do
  # Reload browser tabs when matching files change.
  config :runeshare, RuneshareWeb.Endpoint,
    live_reload: [
      web_console_logger: true,
      patterns: [
        # Static assets, except user uploads
        ~r"priv/static/(?!uploads/).*\.(js|css|png|jpeg|jpg|gif|svg)$"E,
        # Gettext translations
        ~r"priv/gettext/.*\.po$"E,
        # Router, Controllers, LiveViews and LiveComponents
        ~r"lib/runeshare_web/router\.ex$"E,
        ~r"lib/runeshare_web/(controllers|live|components)/.*\.(ex|heex)$"E
      ]
    ]
end

# ## Production logging
#
# Fly collects stdout (`fly logs`). One JSON object per line, so a log shipper
# or `fly logs | jq` can filter on fields; LOG_FORMAT=text gives the plain
# console format instead. LOG_LEVEL (debug/info/warning/error) defaults to info.
# Metadata is an allow-list: nothing else attached to a log call is printed.
if config_env() == :prod do
  log_levels = %{"debug" => :debug, "info" => :info, "warning" => :warning, "error" => :error}
  config :logger, level: Map.get(log_levels, System.get_env("LOG_LEVEL", "info"), :info)

  if System.get_env("LOG_FORMAT", "json") == "json" do
    config :logger, :default_handler,
      formatter:
        LoggerJSON.Formatters.Basic.new(
          metadata: [
            :request_id,
            :user_id,
            :live_view,
            :event,
            :ash_action,
            :outcome,
            :duration_ms,
            :actor_id,
            :record_id,
            :error_class,
            :slow_query_ms,
            :source
          ]
        )
  end
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :runeshare, Runeshare.Repo,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    # For machines with several cores, consider starting multiple pools of `pool_size`
    # pool_count: 4,
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"

  # Every other host name (www., the fly.dev name) redirects here.
  config :runeshare, :canonical_host, host

  config :runeshare, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :runeshare, RuneshareWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://bandit.hexdocs.pm/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ],
    secret_key_base: secret_key_base

  config :ash,
    keyset_signing_secret:
      :crypto.mac(
        :hmac,
        :sha256,
        System.get_env("SECRET_KEY_BASE") ||
          raise("environment variable SECRET_KEY_BASE is missing"),
        "ash keyset signing"
      )

  config :runeshare,
    token_signing_secret:
      System.get_env("TOKEN_SIGNING_SECRET") ||
        raise("Missing environment variable `TOKEN_SIGNING_SECRET`!")

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :runeshare, RuneshareWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://plug.hexdocs.pm/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :runeshare, RuneshareWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.
end
