---
name: parallel-agents
description: "Use this skill before running the app, starting or stopping a dev server, picking a port or URL, running tests, or creating/working inside a git worktree. Covers development slots, the port map, and how several agents share this repo without colliding."
---

## The one rule

**Never assume port 4000 or database `runeshare_dev`.** Run this first:

```sh
mix runeshare.slot
```

It prints the ports, databases and URLs *this checkout* owns. Several agents work
this repo at once from sibling worktrees, and slot 0's app is somebody else's app.

## Slots

A slot is `RUNESHARE_SLOT`, an integer 0..9, read from the checkout's `.env`. Everything
derives from it — `Runeshare.Slot` holds the arithmetic, `config/runtime.exs` applies it.

| Slot | Dev server | LiveDebugger | Test endpoint | Dev DB | Test DB |
|---|---|---|---|---|---|
| 0 (main checkout) | 4000 | 4020 | 4040 | `runeshare_dev` | `runeshare_test` |
| 1 | 4001 | 4021 | 4041 | `runeshare_dev_1` | `runeshare_test_1` |
| N | 4000+N | 4020+N | 4040+N | `runeshare_dev_N` | `runeshare_test_N` |

`PORT` still wins over the slot if it is set. With neither set, `mix phx.server`
probes 4000..4099 for a free port and logs which one it took — convenient for a
human, but it means the port is not knowable in advance, which is why agent
worktrees always get an explicit slot.

Isolated per slot: the dev and test databases, all three ports, `_build`, `deps`.
Shared on purpose: the postgres container, the Hex cache, and the Playwright browser cache.

## Creating a worktree

```sh
bin/agent-worktree new <name>        # next free slot
bin/agent-worktree new <name> --slot 4
bin/agent-worktree list              # every slot, its port, whether a server is up
bin/agent-worktree rm <name>         # worktree + branch + both databases
```

`new` creates `../runeshare-wt-N` on branch `agent/<name>`, writes `.env` with the slot,
symlinks the shared caches, and runs `mix setup` (deps, database, assets, seeds).

Every `mix` command inside the worktree picks up the slot from `.env` on its own —
`config/runtime.exs` loads it and writes it into the environment. Nothing to export.

**Claude itself is the exception.** `.mcp.json` points tidewave and ash_ai at
`${RUNESHARE_PORT:-4000}`, and that expansion happens in the shell that launches Claude,
before any Elixir runs. Start Claude with the env loaded:

```sh
cd ../runeshare-wt-2 && set -a && . ./.env && set +a && claude   # bash/zsh
```

A Claude started without `RUNESHARE_PORT` will happily connect to slot 0's app and report
another agent's data as its own.

Confirm the wiring before trusting an MCP tool:

```sh
claude mcp list        # the URL must carry this slot's port
```

`rm` refuses while a server is up on the slot, while the worktree is dirty, or
while the branch has commits that are not in `main`. Pass `--force` to override.

## Starting and stopping servers

CLAUDE.md says never start or stop the Phoenix application. That rule is
**slot-scoped**: you may start and stop the server for *your own* slot; never touch
another slot's.

Check before assuming anything is yours:

```sh
lsof -ti:$(mix runeshare.slot | awk '/dev server/ {split($3,a,":"); print a[3]}')
```

The shared containers are started once with `docker compose up -d`, which is
idempotent. **Never run `docker compose down`** — it takes every other agent's
database with it.

## Tests

Each slot has its own test database, so `mix test` runs concurrently across slots
with no coordination. Two cautions:

- Playwright browser tests launch real Chromium instances. Two slots running them
  at once is fine; five is not. Check `bin/agent-worktree list` first.
- `MIX_TEST_PARTITION` still works and composes with the slot (test port becomes
  `4040 + slot + 10 * partition`). Only CI uses it.

## When something is on the wrong port

Symptoms: tidewave returns data you did not create, a LiveView change does not show
up in the browser, a test writes to a database another agent is reading.

1. `mix runeshare.slot` — what does this checkout own?
2. `bin/agent-worktree list` — who else is running?
3. `cat .env` — is `RUNESHARE_SLOT` set, and does `RUNESHARE_PORT` match?
4. `claude mcp list` — did the MCP URL pick up `RUNESHARE_PORT`?

Almost always the answer is that Claude was started without sourcing `.env`.
