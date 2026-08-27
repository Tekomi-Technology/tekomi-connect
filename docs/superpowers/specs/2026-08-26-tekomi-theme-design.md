# Tekomi Theme Conversion — Design

Date: 2026-08-26
Branch: `feature/custom-interface`
Status: Approved by user, pending implementation plan

## Purpose

Re-skin the entire Chatwoot interface (dashboard, widget defaults, portal
defaults) to match the visual identity of the Tekomi.vn marketing site:
deep navy backgrounds, teal accent, Inter/InterDisplay typography (already
present), and a rounder, softer shape language. This is a full rebrand of
a self-hosted deployment ("dự án này" = this Chatwoot instance), not a
per-tenant theming feature.

Source reference for the palette: `Tekomi - Trang chu (standalone).html`
and `Tekomi.vn_Static HTML website project/` (untracked files at repo
root, not part of the Chatwoot codebase — kept only as a design
reference).

## Reference palette (Tekomi)

| Token | Hex | Use in Tekomi |
|---|---|---|
| navy | `#0B1F3A` | darkest background |
| navy-2 | `#0E2A4D` | mid background |
| navy-3 | `#123258` | lightest background of the navy family |
| teal | `#11B8C8` | primary accent |
| teal-d | `#0E9AA8` | accent hover/active |
| teal-l | `#E6F8FA` | accent tint background |
| orange | `#E8641E` | rare secondary accent (not adopted — see Out of scope) |
| radius | `16px` | buttons, cards, inputs |
| shadow | `0 18px 50px -20px rgba(11,31,58,.28)` | elevated surfaces |
| heading font | Manrope | not adopted — see below |
| body font | Inter | already Chatwoot's body font |

## Current Chatwoot theming architecture (as found)

- Color tokens are CSS custom properties defined once in
  `app/javascript/dashboard/assets/scss/_next-colors.scss`, under a
  `:root` block (light mode) and a `.dark` block (dark mode, activated by
  Tailwind's `darkMode: 'class'`).
- `theme/colors.js` maps those CSS vars into Tailwind color utilities
  under the `n` namespace (`n-slate`, `n-iris`, `n-teal`, `n-amber`,
  `n-ruby`, `n-blue`, `n-violet`, `n-gray`, plus structural tokens like
  `n-background`, `n-surface-1/2`, `n-solid-*`, `n-border-*`,
  `n-text-*`).
- This single token set is shared by the dashboard, the portal
  (`app/javascript/portal/application.scss` imports it), and (per
  `tailwind.config.js` `content` globs) enterprise views. It is the
  primary surface for this change.
- `n-teal-9` is already the primary/CTA button color and the
  "online/active" status color throughout `components-next` (the
  current, non-deprecated component set). `n-iris` is used exclusively
  for AI/Copilot/Captain features — a distinct semantic meaning, not a
  general brand color.
- A legacy blue scale (`woot-*`, from `@radix-ui/colors` "blue") still
  exists in `theme/colors.js` and is referenced in 5 files. Per
  CLAUDE.md, the non-`components-next` UI is being deprecated.
- The chat widget (`app/javascript/widget/`) and its default accent
  (`Channel::WebWidget#widget_color`, DB default `#1f93ff`) and the
  portal's default accent (`Portal::DEFAULT_COLOR`) are **already
  per-instance customizable** (ColorPicker in inbox/portal settings).
  They do not consume the `n-*` token set for their brand color — each
  inbox/portal stores its own.
- No custom `borderRadius` scale is currently defined in
  `tailwind.config.js` (Tailwind defaults apply). Radius usage today is
  dominated by `rounded-lg` (169 occurrences) and `rounded-xl` (80),
  both smaller than Tekomi's 16px.
- Fonts: Inter and InterDisplay are already self-hosted
  (`app/javascript/shared/assets/fonts/`) and wired into
  `tailwind.config.js` (`fontFamily.sans`, `.inter`, `.interDisplay`).
  Manrope is not present.

## Decisions (confirmed with user)

1. **Navy background covers every screen**, in both light and dark
   mode — not scoped to chrome (sidebar/header) only, and not scoped to
   selected sections the way the Tekomi marketing site itself alternates
   white/navy/gray sections. This was asked twice and confirmed both
   times.
2. **Light mode and dark mode are both navy**, differentiated only by
   depth: light mode uses the lighter end of the navy family
   (`navy-3` / `navy-2`), dark mode uses the darkest (`navy` /
   `#0B1F3A` and below). The light/dark toggle stops being a
   "light-background vs dark-background" switch and becomes a
   "medium-navy vs deep-navy" switch. This is a deliberate, confirmed
   trade-off, not an oversight.
3. **Accent color**: reuse Radix UI Colors' existing "Cyan" scale
   (already an installed dependency via `@radix-ui/colors`,
   `cyan-9 = #00a2c7`) as the new source for the `--teal-*` CSS
   variables, replacing the current Radix "Teal" scale
   (`teal-9 = #12a594`). Cyan is the closest existing, accessibility-
   tested 12-step Radix scale to Tekomi's `#11B8C8`. This is a values-
   only swap inside `_next-colors.scss`; no component code changes,
   since every consumer already reads `n-teal-*`.
4. **Typography**: no change. Inter (body) already matches. InterDisplay
   stays as the heading font instead of adding Manrope, to avoid a new
   font dependency (user's explicit choice).
5. **Shape**: extend `tailwind.config.js`'s `theme.extend.borderRadius`
   so the existing `rounded-*` scale renders larger app-wide. Target
   values (implementation should treat these as a starting point, tuned
   during visual QA rather than applied blindly):
   `md` → `10px`, `lg` → `16px` (Tekomi's value, and the most-used
   class today), `xl` → `20px`, `2xl` → `24px`. This is a scale-level
   change — no per-component class edits, since hundreds of existing
   `rounded-lg`/`rounded-xl` usages inherit the new sizes automatically.
6. **Shadow**: add a new `boxShadow` token (e.g. `shadow-brand`) using
   Tekomi's navy-tinted soft shadow formula, applied at implementation
   time to elevated surfaces (modals, dropdowns, popovers, primary
   cards). Not a blanket replacement of every existing shadow utility.
7. **Widget & portal default accent**: change the *default value only*
   (`Channel::WebWidget` default `widget_color`, `Portal::DEFAULT_COLOR`)
   to Tekomi teal. Per-inbox/per-portal customization is preserved —
   this is explicitly not a forced override, per user's confirmed
   choice.
8. **Semantic colors untouched**: `iris` (AI features), `ruby` (error),
   `amber` (warning), `blue` (info), `violet` stay as they are. Their
   meaning would break if recolored, and the user's request was about
   brand identity, not state semantics.
9. **Legacy `woot-*` scale left as-is** (5 files, marked for
   deprecation per CLAUDE.md) — not worth reworking a system already
   scheduled for removal.

## Required technical consequence: text/border contrast must invert

Making the *background* navy is not sufficient on its own — every token
currently tuned for "dark text/borders on a light background" must be
re-tuned for "light text/borders on a dark background", in **both**
`:root` and `.dark`, specifically:

- `--slate-*` (primary text/neutral scale): `_next-colors.scss` already
  contains a full dark-mode slate scale (light-on-dark, `.dark` block,
  lines 158–169) that has presumably already been contrast-checked.
  The implementation should reuse that existing light-text scale as the
  base for the new `:root` (medium navy) and derive an even
  higher-contrast variant for the new `.dark` (deep navy), rather than
  inventing new contrast values from scratch.
- `--gray-*`, `--background-color`, `--surface-1/2`, `--surface-active`,
  `--card-color`, `--solid-1/2/3`: retint to the navy family
  (`background-color` = darkest of the two modes' navy, `surface-1/2` =
  progressively lighter navy steps, mirroring the existing elevation
  order which currently goes light→lighter).
- `--border-weak`, `--border-strong`, `--border-container`,
  `--label-background`, `--label-border`, alpha tokens
  (`--alpha-1/2/3`, `--black-alpha-*`, `--white-alpha`): currently
  low-opacity *black* overlays for a light background; need to become
  low-opacity *white* overlays for a dark background (standard dark-UI
  pattern), in both modes.
- `--text-blue`, `--text-purple`, `--text-amber` (currently near-black
  values meant to sit on white chips): must be re-tuned to remain
  legible on navy chip backgrounds — these are the highest-risk items
  for being missed, since they're easy to overlook as "just text color"
  separate from the main background change.

This pass is the bulk of the implementation risk and effort — not the
navy background swap itself.

## Files touched (implementation map)

| File | Change |
|---|---|
| `app/javascript/dashboard/assets/scss/_next-colors.scss` | Retint `--teal-*` (both modes) to Radix Cyan values; retint `--background-color`, `--surface-*`, `--card-color`, `--solid-*`, `--gray-*` to the navy family (both modes); invert `--slate-*`/text/border/alpha tokens for contrast (both modes) |
| `theme/colors.js` | No changes expected — `n.teal` and structural tokens already read from CSS vars |
| `tailwind.config.js` | Add `theme.extend.borderRadius` scale bump; add `boxShadow.brand` (or similar) using Tekomi's shadow formula |
| `app/models/channel/web_widget.rb` | Change `widget_color` column default to Tekomi teal (requires a migration for `change_column_default`) |
| `app/models/portal.rb` | Change `DEFAULT_COLOR` constant to Tekomi teal (no migration — Ruby-level fallback) |
| `app/javascript/widget/assets/scss/woot.scss` | Structural updates (radius, any hardcoded shadow) — widget color itself stays dynamic per inbox, not touched here |
| `app/javascript/portal/application.scss` | Verify it inherits the shared tokens; sweep any hardcoded `bg-white`/light-only styles found at implementation time |

## Out of scope (explicitly)

- Adding Manrope as a heading font.
- Forcing widget/portal colors (removing the per-inbox/per-portal
  ColorPicker).
- Recoloring semantic state colors (error/warning/info/AI-feature accent).
- Reworking the legacy `woot-*` color scale or the 5 files still using it.
- Email templates, PDF exports, or any other stylesheet not part of the
  dashboard/widget/portal token system, unless raised separately.
- Section-by-section navy (like the actual Tekomi site does) — this
  design applies navy uniformly to every screen per the user's explicit
  choice.

## Risks / things to verify during implementation

- **Contrast/accessibility**: every retuned text-on-navy and
  border-on-navy pair needs a contrast check (not just "looks dark
  enough"), especially the semantic text tokens (`text-blue`,
  `text-purple`, `text-amber`) which are easy to miss.
- **Visual QA burden**: because the radius change and the background
  change are both scale-level (not per-component), the actual visual
  result across dozens of screens (settings pages, tables, modals,
  forms) needs a manual pass after implementation — some components may
  have hardcoded `bg-white`/`text-black`/`shadow-sm` that bypass the
  token system entirely and will need individual fixes.
- **Loss of light/dark contrast familiarity**: users accustomed to a
  light SaaS dashboard will see navy in both modes; this was confirmed
  intentional but is worth calling out again before implementation
  starts, since it's a significant departure from typical product
  conventions.
- **Widget/portal migration**: changing a Rails column default via
  migration does not retroactively change already-created inboxes'
  `widget_color` — only new inboxes get Tekomi teal by default. This
  matches the "default only" decision and is not a bug.
