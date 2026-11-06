---
name: testing
description: "Use this skill when writing or modifying tests. Covers shared builders, naming conventions, and testing philosophy for this project."
---

## Testing philosophy

Tests read like specifications: setup, action, assertion, minimal ceremony.
One happy-path test plus obvious failure cases. No elaborate factories, custom DSLs
or speculative edge cases. Test through code interfaces — the same entry point real
callers use — not internals.

## Shared builders

`test/support/builders.ex` (`Runeshare.Test.Builders`), imported automatically by
`Runeshare.DataCase` and `RuneshareWeb.ConnCase`.

| Builder | Purpose |
|---------|---------|
| `register_user!(opts)` | Runs the real `:register_with_google` action with fake Google claims. Opts: `:email`, `:name` |
| `share_preset!(author, attrs)` | Shares a preset as `author`. Defaults to a valid Watchdog alarm |

Do not duplicate these in test modules. A helper needed by 2+ test files goes into
`builders.ex`. A helper that calls a bang function gets a bang name.

## Test structure

- `describe` blocks group by action or feature.
- `use Runeshare.DataCase, async: true` for domain tests,
  `use RuneshareWeb.ConnCase, async: true` for LiveView/controller tests.

## What to test more thoroughly

- **Authorization**: every update/destroy needs a test proving another user is
  forbidden, and every create a test proving anonymous visitors are forbidden.
- **LiveViews**: mount, primary action, auth redirects. Skip only pure static pages.
- **External services** (Google OAuth): never hit the real service. Drive the
  registration action directly with fake `user_info`, as `register_user!/1` does.

## Patterns

### LiveView / page tests

Use **PhoenixTest** (imported by `RuneshareWeb.ConnCase`), not raw `Phoenix.LiveViewTest`:

```elixir
conn
|> log_in_user(user)
|> visit(~p"/tile-markers/new")
|> fill_in("Title", with: "Raksha tiles")
|> click_button("Save")
|> assert_has("h1", text: "Raksha tiles")
```

Redirect checks: `visit(path) |> assert_path(~p"/sign-in")`.
Content loaded with `stream_async`/`assign_async`/`start_async` needs `assert_has(..., timeout: 2_000)`
(it only waits when the element isn't there yet; 500 ms flaked under load). Fall back to `unwrap/2`
only for what PhoenixTest can't express.

### Browser tests (Playwright)

For flows that need real JS (colocated hooks such as copy-to-clipboard), use
`use PhoenixTest.Playwright.Case, async: true` + `import RuneshareWeb.BrowserHelpers`
(`log_in_user(conn, user)`). Debug with `@tag trace: :open` or `screenshot/2`.
Needs `npm --prefix assets install && npm --prefix assets exec playwright install chromium`
(part of `mix setup`). Keep these few — they are slow.
