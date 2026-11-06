---
name: credo-checks
description: "Use this skill when `mix credo` or `mix precommit` reports an issue, when deciding whether to suppress a check, or when adding/enabling Credo checks. Covers the four check suites in this project and the suppression ladder."
---

## The suites

`mix credo --strict` runs 183 checks from four sources. All of them are listed
explicitly in `.credo.exs` under `checks.enabled` — Credo treats an explicit
`enabled` list as authoritative and **discards any check a plugin would inject**,
so a check that is not in that list is not running, no matter what its plugin does.

| Suite | What it is for |
|---|---|
| Credo | Standard Elixir style, refactoring and warning checks. |
| **ExSlop** | ~35 checks aimed at AI-written code: blanket rescues, narrator comments, N+1 queries, identity passthroughs, redundant `Enum` chains. |
| **ExDNA** | Clone detection across modules, AST-aware. A clone report means: extract the shared logic into a helper. |
| **bylaw_credo** | Invariants: Ecto/Ash query shape, HEEx accessibility (`alt`, `rel="noopener"`, labels), typespec discipline. |
| **llamex** | Eight checks for LLM-authored Ash/Phoenix code: ad-hoc Ash queries, authorization bypass, `self()` in LiveViews, redundant wrappers. |

HEEx checks read `~H` sigils inside `.ex` files, which is where all but four of this
app's templates live. The `Bylaw.Credo.Plugin.HEExSources` plugin (which would add
the four standalone `.html.heex` files) is deliberately **off**: it feeds those files
to every check, including plain-Elixir ones, which then report ~90 false positives
on markup.

## Parked checks

`.credo.exs` carries a commented block of checks that are not enabled, each with the
violation count measured on the tree at the time. Treat it as a backlog, not as
decoration. Two groups will probably never move:

- `Bylaw...Elixir.NoRaise` and `NoTryRescue` — this project uses bang functions on
  purpose (see the `testing` skill).
- `Bylaw...Testing.NoDescribeBlocks`, `NoSetupInTests`, `NoTestsInTestDir` — the
  `testing` skill mandates `describe` and `setup` blocks.

To re-measure before enabling one, run credo with a throwaway config that turns the
candidate on, and count by check:

```sh
mix credo suggest --config-file /tmp/measure.credo.exs --config-name measure \
  --format json --strict | jq -r '.issues[].check' | sort | uniq -c | sort -rn
```

Two bylaw checks crash on this tree (`Ecto.ContextOwnsSchemaQueries` and
`Elixir.SimpleTaggedTupleValues`, `FunctionClauseError` inside the check itself in
bylaw_credo 0.4.0). They are left out of `.credo.exs` entirely.

## The suppression ladder

Work down it. Do not start at the bottom.

1. **Fix the code.** Most findings are right. A `<button>` without `type` really does
   submit the enclosing form; `Enum.map |> Enum.uniq` really does build a list twice.
2. **Suppress one definition, with a reason.** Use the `DisableForNextDefinition`
   plugin, which scopes to a whole function clause rather than one line and does not
   break when the function grows:

   ```elixir
   # credo:disable-for-next-definition Llamex.Check.NoDBWorkInMemory
   # Admin export of every preset — reading the whole table is the point.
   def perform(%Oban.Job{}) do
   ```

   The comment explaining *why* is not optional. Omit the check name to suppress
   everything in that definition — rarely what you want.

   Llamex's own `@llamex_one_liner_allowed true` attribute also works, but the
   compiler warns that the attribute is unused, which fails `--warnings-as-errors`.
   Use the credo comment instead.

3. **Change `.credo.exs`.** Only with human sign-off. Disabling a check for the whole
   project because one call site is awkward is how the suite stops being worth running.

## Before finishing a chunk of work

```sh
mix precommit
```

Runs compile (warnings as errors), unused deps, format, the skills drift check,
`mix credo --strict`, and the tests.
