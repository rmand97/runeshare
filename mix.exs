defmodule Runeshare.MixProject do
  use Mix.Project

  def project do
    [
      app: :runeshare,
      version: "0.1.0",
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader],
      consolidate_protocols: Mix.env() != :dev,
      usage_rules: usage_rules()
    ]
  end

  defp usage_rules do
    # Framework usage rules are surfaced via Claude Code skills only.
    # CLAUDE.md is hand-maintained with project-specific content; sync does not touch it.
    [
      skills: [
        location: ".claude/skills",
        build: [
          "ash-framework": [
            description:
              "Use this skill working with Ash Framework or any of its extensions. Always consult this when making any domain changes, features or fixes.",
            usage_rules: [:ash, ~r/^ash_/]
          ],
          "phoenix-framework": [
            description:
              "Use this skill working with Phoenix Framework. Consult this when working with the web layer, controllers, views, liveviews etc.",
            usage_rules: [:phoenix, ~r/^phoenix_/]
          ]
        ]
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Runeshare.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:picosat_elixir, "~> 0.2"},
      {:sourceror, "~> 1.13", only: [:dev, :test]},
      {:live_toast, "~> 0.11.0"},
      {:live_select, "~> 1.7"},
      {:tidewave, "~> 0.9.2", only: [:dev]},
      {:usage_rules, "~> 1.3", only: [:dev]},
      {:ash_ai, "~> 1.5"},
      {:ash_admin, "~> 1.4"},
      {:ash_authentication_phoenix, "~> 2.17"},
      {:ash_authentication, "~> 4.15"},
      {:ash_phoenix, "~> 2.3"},
      {:ash_postgres, "~> 2.15"},
      {:ash, "~> 3.37"},
      {:igniter, "~> 0.8", only: [:dev, :test]},
      {:phoenix, "~> 1.8.16"},
      {:phoenix_ecto, "~> 4.7"},
      {:ecto_sql, "~> 3.14"},
      {:postgrex, "~> 0.22"},
      {:phoenix_html, "~> 4.4"},
      {:phoenix_live_reload, "~> 1.7", only: :dev},
      {:phoenix_live_view, "~> 1.2.13"},
      {:lazy_html, "~> 0.1", only: :test},
      {:phoenix_test, "~> 0.14", only: :test, runtime: false},
      {:phoenix_test_playwright, "~> 0.19", only: :test, runtime: false},
      {:phoenix_live_dashboard, "~> 0.9"},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.5", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:daisyui,
       github: "saadeghi/daisyui",
       tag: "v5.7.50",
       sparse: "packages/bundle",
       app: false,
       compile: false,
       depth: 1},
      {:req, "~> 0.7"},
      # File attachments (preset cover images). Not on Hex yet (0.1.0) — pin the ref.
      {:ash_storage,
       github: "ash-project/ash_storage", ref: "86887abaa1a1d86b14d67ad5cfde1e2f13ce5dd5"},
      {:req_s3, "~> 0.2"},
      {:telemetry_metrics, "~> 1.2"},
      {:telemetry_poller, "~> 1.3"},
      {:gettext, "~> 1.0"},
      {:jason, "~> 1.4"},
      {:dns_cluster, "~> 0.3"},
      {:bandit, "~> 1.14"},
      {:dotenvy, "~> 1.2"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_slop, "~> 0.4", only: [:dev, :test]},
      {:ex_dna, "~> 1.5", only: [:dev, :test], runtime: false},
      {:bylaw_credo, "== 0.4.0", only: [:dev, :test], runtime: false},
      # Not published to Hex, and the author calls it vibe-coded — pin the ref.
      {:llamex,
       github: "dmitriid/llamex",
       ref: "1953a8d0a375c982848390cd000ae2a184e0e686",
       only: [:dev, :test],
       runtime: false},
      {:canonical_tailwind, "~> 0.3", only: [:dev, :test], runtime: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ash.setup", "assets.setup", "assets.build", "run priv/repo/seeds.exs"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      # Browser (Playwright) tests load the built bundle, so rebuild it first.
      test: ["ash.setup --quiet", "esbuild runeshare", "tailwind runeshare", "test"],
      "assets.setup": [
        "tailwind.install --if-missing",
        "esbuild.install --if-missing",
        "cmd npm --prefix assets install",
        "cmd npm --prefix assets exec playwright install chromium"
      ],
      "assets.build": ["compile", "tailwind runeshare", "esbuild runeshare"],
      "assets.deploy": [
        "tailwind runeshare --minify",
        "esbuild runeshare --minify",
        "phx.digest"
      ],
      precommit: [
        "compile --warnings-as-errors",
        "deps.unlock --check-unused",
        "format --check-formatted",
        # precommit runs in :test; usage_rules is :dev-only, so sync in a :dev subprocess.
        "cmd env MIX_ENV=dev mix usage_rules.sync --yes",
        # Only the generated skills; hand-written ones are edited by people.
        "cmd git diff --exit-code .claude/skills/ash-framework .claude/skills/phoenix-framework",
        # credo in a subprocess so its started :credo app doesn't clash with the test boot.
        "cmd mix credo --strict",
        "test"
      ]
    ]
  end
end
