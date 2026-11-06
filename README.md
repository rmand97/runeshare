# RuneShare

Share RuneScape 3 plugin setups: **Watchdog alarm strings** and **tile marker presets**.
Sign in with Google, paste an import string, and others can copy it straight into their plugin.

Phoenix 1.8 · LiveView 1.2 · Ash 3 (AshPostgres, AshAuthentication, AshAdmin, AshAI) · Tailwind 4 + DaisyUI 5.

## Getting started

Tooling versions are pinned in `mise.toml` (`mise install`).

```sh
docker compose up -d          # Postgres on localhost:5432
cp .env.example .env          # then fill in GOOGLE_CLIENT_ID / GOOGLE_CLIENT_SECRET
mix setup                     # deps, database, assets, Playwright, seeds
mix phx.server                # http://localhost:4000 (see `mix runeshare.slot`)
```

### Google OAuth

Create an OAuth client at <https://console.cloud.google.com/apis/credentials>
(type "Web application") with authorized redirect URI
`http://localhost:4000/auth/user/google/callback`. Put the client id and secret in `.env`.

## Development

- `mix precommit` — compile (warnings as errors), unused deps, format, skills drift, `credo --strict`, tests.
- `mix runeshare.slot` — ports/databases this checkout owns.
- `bin/agent-worktree new <name>` — isolated worktree for a parallel agent.
- `/admin` (dev only) — AshAdmin. `/dev/dashboard` — LiveDashboard.

Agent rules live in `CLAUDE.md` and `.claude/skills/`.

## Production

Runs on Fly.io (app + self-run Postgres) with cover images in Tigris: <https://runeshare.dk>.
`fly deploy` ships a new version. Setup, costs, backups and secrets: [DEPLOY.md](DEPLOY.md).
