# Deploying RuneShare

Production runs on [Fly.io](https://fly.io) in `ams` (Amsterdam):

| Piece | What | Approx. cost / month |
|---|---|---|
| `runeshare` | The Phoenix release, `shared-cpu-1x` / 512 MB, sleeps when idle | ~$3.3 while running |
| `runeshare-db` | Official `postgres:17-alpine` image, `shared-cpu-1x` / 256 MB, private only | ~$2.2 |
| `pg_data` volume | 1 GB, daily snapshots kept 14 days | ~$0.15 + snapshots |
| `runeshare-covers` | Public Tigris bucket for cover images | free tier (5 GB, 10k writes, 100k reads) |

Site: <https://runeshare.dk>. Config: `fly.toml` (app) and `fly-db/fly.toml` (database).

## Domain

`runeshare.dk` is registered with Dandomain, which also hosts its DNS (nameservers
`ns.dandomain.dk`, `ns2.dandomain.dk`):

| Name | Type | Value |
|---|---|---|
| `runeshare.dk`, `www.runeshare.dk` | A | `66.241.125.243` (Fly shared IPv4) |
| `runeshare.dk`, `www.runeshare.dk` | AAAA | `2a09:8280:1::1ed:2558:0` (the app's IPv6) |

Fly issues the TLS certificates (`fly certs list`). `PHX_HOST` in `fly.toml` is the
canonical host: `RuneshareWeb.Plugs.CanonicalHost` 301-redirects every other name
(`www.`, `runeshare.fly.dev`) to it.

## Deploy a new version

```sh
fly deploy
```

`release_command` runs `/app/bin/migrate` on a one-off machine first, so new
migrations apply before the new release takes traffic. Check with `fly status`
and `fly logs`.

## Day-to-day

```sh
fly logs                                   # app logs
fly ssh console -C "/app/bin/runeshare remote"   # IEx inside the running app
fly logs -a runeshare-db                   # database logs
fly secrets list                           # names only
```

### Logs

Production logs are one JSON object per line (`LoggerJSON.Formatters.Basic`), level
`info`. Every Ash write logs one line: action, outcome, duration, actor id and record
id (`Runeshare.ActionLog`); forbidden attempts are warnings, crashes errors. Reads,
SQL and LiveView events stay at `debug`; queries over 200 ms log a `slow query` warning.
Emails, tokens and action inputs are never logged — users appear by id.

```sh
fly logs                                                     # live tail
fly logs --no-tail | jq -r 'select(.severity=="warning" or .severity=="error") | .message'
fly logs --no-tail | jq -r 'select(.metadata.actor_id=="<user id>") | .message'
fly secrets set LOG_LEVEL=debug     # temporarily: every read and Ash action (restarts)
fly secrets set LOG_FORMAT=text     # plain lines instead of JSON
```

`fly logs` only shows recent output; ship logs elsewhere (e.g. fly-log-shipper) to keep them.

The app machine stops after a few idle minutes and starts on the next request
(a second or two). The database machine always runs.

## Database

Postgres is not managed by Fly: it's the stock image on a volume. The app
reaches it at `runeshare-db.internal:5432` over Fly's private IPv6 network
(`ECTO_IPV6=true`); it has no public address.

- **Backups**: Fly snapshots the volume daily and keeps 14 days
  (`snapshot_retention` in `fly-db/fly.toml`). List them with
  `fly volumes snapshots list <volume id> -a runeshare-db`
  (`fly volumes list -a runeshare-db` shows the id).
- **Restore**: create a volume from a snapshot
  (`fly volumes create pg_data --snapshot-id <id> -a runeshare-db -r ams`),
  destroy the old machine and `fly deploy -c fly-db/fly.toml` again.
- **Off-site dump** (e.g. before risky changes):
  ```sh
  fly proxy 15432:5432 -a runeshare-db      # in one terminal
  pg_dump postgres://runeshare:<password>@localhost:15432/runeshare > dump.sql
  ```
  The password is the `POSTGRES_PASSWORD` secret on `runeshare-db` (also inside
  the app's `DATABASE_URL`); Fly won't show it, so keep a copy in your password manager.
- **Tuning**: sized for 256 MB (`[processes]` in `fly-db/fly.toml`). If it runs
  out of memory, `fly scale memory 512 -a runeshare-db`.

## Cover images (Tigris)

`fly storage create --public` set these secrets on the app: `BUCKET_NAME`,
`AWS_ENDPOINT_URL_S3`, `AWS_REGION`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`.
`config/runtime.exs` points `Preset`'s storage at the bucket under `covers/`,
and images are served straight from `https://runeshare-covers.t3.tigrisfiles.io`
(override with a `STORAGE_PUBLIC_URL` secret, e.g. for a custom domain).

## Secrets

| Secret | Notes |
|---|---|
| `SECRET_KEY_BASE`, `TOKEN_SIGNING_SECRET` | Random; changing them signs everyone out |
| `DATABASE_URL` | `ecto://runeshare:<password>@runeshare-db.internal:5432/runeshare` |
| `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` | The Google OAuth client. Its authorized redirect URIs must include `https://runeshare.dk/auth/user/google/callback` |
| `ADMIN_EMAILS` | Comma-separated; these accounts become moderators on sign-in |
| Tigris (5) | Set by `fly storage create` |

## Setting it up from scratch

```sh
fly apps create runeshare-db
fly secrets set POSTGRES_PASSWORD=$(openssl rand -hex 24) -a runeshare-db --stage
(cd fly-db && fly deploy -c fly.toml -a runeshare-db --ha=false)

fly apps create runeshare
fly storage create --public -a runeshare -n runeshare-covers
fly secrets set -a runeshare --stage SECRET_KEY_BASE=... TOKEN_SIGNING_SECRET=... \
  DATABASE_URL=ecto://runeshare:<password>@runeshare-db.internal:5432/runeshare \
  GOOGLE_CLIENT_ID=... GOOGLE_CLIENT_SECRET=... ADMIN_EMAILS=...
fly deploy --ha=false
```

`--ha=false` matters: by default Fly creates two machines per app, doubling the cost.
