# RuneShare

**<https://runeshare.dk>** — share and copy RuneScape 3 plugin setups:
**Watchdog alarm strings** and **tile marker presets**.

Paste the export string from your plugin, and other players can copy it straight
back into theirs. Community-made, not affiliated with Jagex.

## What you can do

- **Browse and copy** Watchdog alarms and tile marker presets without an account.
  Search by title, filter by tag (`vorago`, `zamorak`, … — common nicknames map to
  the same tag), and sort by newest, most liked or most copied.
- **Sign in** with Google, GitHub, Discord or Twitch to share your own setups.
  The same verified email is the same account, whichever you use.
- **Share** a preset with a title, description, up to five tags and a cover image.
  RuneShare checks that the string is a valid export and reads the alert or
  preset names out of it.
- **Edit** your presets. Every change keeps the old version viewable, so nobody
  loses a setup that worked for them.
- **Like and comment** on other players' presets. Likes, comments and new shares
  show up live.
- **Report** a preset that is broken, spam or offensive; moderators review reports.

## Found a problem or have an idea?

| What | Where |
|---|---|
| A preset is broken, spam or offensive | The **Report** button on the preset's page |
| The site is broken or behaves oddly | [Report a bug](https://github.com/rmand97/runeshare/issues/new?template=bug_report.yml) |
| An idea or improvement | [Suggest it](https://github.com/rmand97/runeshare/issues/new?template=feature_request.yml) |
| Support for another RuneScape 3 plugin | [Ask for a plugin](https://github.com/rmand97/runeshare/issues/new?template=new_plugin.yml) |
| A security problem | [Report it privately](https://github.com/rmand97/runeshare/security/advisories/new) — see [SECURITY.md](SECURITY.md) |

Check the [open issues](https://github.com/rmand97/runeshare/issues) first; a
👍 on an existing one helps more than a duplicate.

## Running it locally

Phoenix 1.8 · LiveView 1.2 · Ash 3 (AshPostgres, AshAuthentication, AshStorage) ·
Tailwind 4 + DaisyUI 5 · Postgres.

Tool versions are pinned in `mise.toml` (`mise install`). You also need Docker
for Postgres and Node for the asset and browser-test tooling.

```sh
docker compose up -d          # Postgres on localhost:5432
cp .env.example .env          # add at least one sign-in provider (below)
mix setup                     # deps, database, assets, Playwright, demo data
mix phx.server                # http://localhost:4000 (see `mix runeshare.slot`)
```

`mix setup` seeds demo users and presets, so the site has content straight away.
Browsing works without signing in.

### Sign-in providers

To sign in locally, create an OAuth app at one or more providers and put its client
id and secret in `.env` (see `.env.example`). Callback URL:
`http://localhost:4000/auth/user/<provider>/callback`.

| Provider | Where |
|---|---|
| Google | <https://console.cloud.google.com/apis/credentials> (type "Web application") |
| GitHub | <https://github.com/settings/developers> → New OAuth App |
| Discord | <https://discord.com/developers/applications> → OAuth2 → Redirects |
| Twitch | <https://dev.twitch.tv/console/apps> |

One is enough; the others' buttons fail until configured. To become a moderator
locally, put your email in `ADMIN_EMAILS` in `.env`.

### Development

- `mix precommit` — what CI runs: compile (warnings as errors), unused deps,
  format, `credo --strict`, tests (including Playwright browser tests).
- `mix sobelow --config` — security scan.
- `mix runeshare.slot` — the ports and databases this checkout uses (several
  checkouts can run side by side).
- `/admin` (dev only) — AshAdmin. `/dev/dashboard` — LiveDashboard.

How the code is organised — resources own their rules, the `Sharing` and
`Accounts` domains are the API, the web layer only calls the domains — is
described in [CLAUDE.md](CLAUDE.md), along with the project conventions.

Pull requests are welcome. For anything bigger than a small fix, open an issue
first so we can agree on the approach.

## Production

Runs on Fly.io (app + self-run Postgres) with cover images in Tigris.
Setup, secrets, backups and costs: [DEPLOY.md](DEPLOY.md).
