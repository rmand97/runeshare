---
name: frontend
description: "Use this skill when building or modifying UI: LiveView templates, components, layouts, CSS, and responsive design. Covers mobile-first patterns, component conventions, Tailwind v4 with DaisyUI, and design system rules for this project."
---

## Mobile-first mandate

Every page and component must work at 320px before scaling up. Base Tailwind
classes target mobile; layer wider layouts with `sm:` (640px), `md:` (768px),
`lg:` (1024px). If it doesn't look right on a phone, it's not done.

- **Grids**: `grid gap-3 sm:grid-cols-2` — never a multi-column grid without a breakpoint prefix.
- **Spacing**: tighter on mobile, grow at breakpoints (`py-8 sm:py-12`).
- **Hover effects**: only behind `sm:` (`sm:hover:border-primary`) — touch has no hover.
- **Buttons, link badges, row hover**: hover/focus-visible looks come from the `interactive` layer at the end of `app.css` (`.btn` variants, `a.badge`, rows with `sm:hover:bg-base-200/60` get a gold left rule). Don't re-add one-off hover classes for those; a `<span class="badge">` is status-only and gets no hover.
- **Touch targets**: at least 44x44px. DaisyUI `btn` sizes handle this.
- **Navigation**: wraps (`flex-wrap`); never `overflow-x-auto` that hides items.

## Tailwind v4 + DaisyUI v5

No `tailwind.config.js`. `assets/css/app.css` uses `@import "tailwindcss" source(none)`
with `@source` lines; DaisyUI is a `@plugin`. Keep that syntax. No `@apply`.

Colours come from the DaisyUI theme variables (`bg-base-100`, `text-primary`,
`badge-primary`, …), not hard-coded hex values, so light/dark and future theme
changes apply everywhere. Theme definitions live in `app.css`.

## Design direction: "Ledger"

Chosen from the mockups in `design/` (reference: `design/01-ledger.html`).
Dense, dark data site in the spirit of TempleOSRS:

- **Theme**: dark is default (light exists). Charcoal `base-100` panels on near-black
  `base-300` page, gold `primary`. Near-square corners, no shadows (`--depth: 0`).
- **Type**: `font-display` (Roboto Condensed) bold uppercase with `tracking-wide`/`tracking-wider`
  for headings, nav and table heads; `font-sans` (Roboto) body; `font-mono` (Roboto Mono)
  for import strings and numbers. Fonts are self-hosted in `priv/static/fonts`.
- **Panels**: every boxed section is `<.panel title=… icon=…>` — gold left rule on a
  `base-200` header bar, optional `:actions` slot. Don't hand-roll that header.
- **Lists**: tables (`table table-sm`) for listings, dropping columns below `sm`/`md`/`lg`;
  `divide-y divide-base-content/5` rows for compact lists. Row hover `sm:hover:bg-base-200/60`.
- **Muted text**: `text-base-content/50`–`/70`, never grey hex values.
- **Badges**: `badge badge-primary badge-sm rounded-sm font-display uppercase tracking-wider`.

## Components

- `core_components.ex`: `<.input>`, `<.button>`, `<.icon name="hero-…">`, `<.header>`, `<.table>`. Always use `<.input>` for form fields; `<.icon>` for icons, never `Heroicons` modules.
- `RuneshareWeb.PresetComponents`: `panel/1`, `avatar/1`, `copy_button/1` (colocated `.CopyToClipboard` hook), `breadcrumbs/1`, `time_ago/1`, `author_name/1`, and per-kind `kind_label/kind_short/kind_heading/kind_icon/kind_path/new_path/plugin_name`. Reuse these rather than re-deriving.
- Repeated markup inside one LiveView → private function component (`defp row(assigns)`). Used by 2+ LiveViews → promote to a module under `lib/runeshare_web/components/`.

## Layout

Every LiveView template starts with
`<Layouts.app flash={@flash} current_user={@current_user}>`. Pass `active={kind}` to highlight
the nav tab and `width="max-w-3xl"` for narrow form pages. `<.flash_group>` lives only in `layouts.ex`.

## JavaScript

No inline `<script>` tags in templates. Use colocated hooks
(`<script :type={Phoenix.LiveView.ColocatedHook} name=".Name">`, see
`PresetComponents.copy_button/1`) or modules under `assets/js/`.
No vendor scripts/CSS via `src`/`href`; bundle through `app.js`/`app.css`.

## Accessibility (enforced by credo HEEx checks)

Buttons need `type` and text or `aria-label`; images need `alt`; inputs need labels;
`target="_blank"` needs `rel="noopener"`; submit forms expose a loading state
(`phx-disable-with` or `phx-submit-loading:` classes).
