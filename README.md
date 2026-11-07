# RuneShare

Share RuneScape 3 plugin setups: **Watchdog alarm strings** and **tile marker presets**.
Sign in with Google, GitHub, Discord or Twitch, paste an import string, and others can copy it straight into their plugin.

Phoenix 1.8 · LiveView 1.2 · Ash 3 (AshPostgres, AshAuthentication, AshAdmin, AshAI) · Tailwind 4 + DaisyUI 5.

## Getting started

Tooling versions are pinned in `mise.toml` (`mise install`).

```sh
docker compose up -d          # Postgres on localhost:5432
cp .env.example .env          # then fill in GOOGLE_CLIENT_ID / GOOGLE_CLIENT_SECRET
mix setup                     # deps, database, assets, Playwright, seeds
mix phx.server                # http://localhost:4000 (see `mix runeshare.slot`)
```

### Sign-in providers

Create an OAuth app at each provider you want to use locally and put its client
id and secret in `.env` (see `.env.example`). Callback URL:
`http://localhost:4000/auth/user/<provider>/callback`.

| Provider | Where |
|---|---|
| Google | <https://console.cloud.google.com/apis/credentials> (type "Web application") |
| GitHub | <https://github.com/settings/developers> → New OAuth App |
| Discord | <https://discord.com/developers/applications> → OAuth2 → Redirects |
| Twitch | <https://dev.twitch.tv/console/apps> |

One is enough to sign in; the others' buttons fail until configured.

## Development

- `mix precommit` — compile (warnings as errors), unused deps, format, skills drift, `credo --strict`, tests.
- `mix runeshare.slot` — ports/databases this checkout owns.
- `bin/agent-worktree new <name>` — isolated worktree for a parallel agent.
- `/admin` (dev only) — AshAdmin. `/dev/dashboard` — LiveDashboard.

Agent rules live in `CLAUDE.md` and `.claude/skills/`.

## Production

Runs on Fly.io (app + self-run Postgres) with cover images in Tigris: <https://runeshare.dk>.
`fly deploy` ships a new version. Setup, costs, backups and secrets: [DEPLOY.md](DEPLOY.md).
