# Tekomi Theme Conversion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Re-skin Chatwoot's dashboard, widget defaults, and portal defaults to Tekomi's navy/teal identity — every screen, both light and dark mode, without breaking per-inbox/per-portal color customization or semantic state colors (error/warning/info/AI accent).

**Architecture:** All visual tokens live in one CSS-variable file (`_next-colors.scss`) consumed by Tailwind via `theme/colors.js`. The current `.dark` block is already a working, contrast-safe "light text on dark background" theme — the strategy is to reuse its values as the base for the new `:root` (rather than inventing new contrast pairs from scratch), hue-shifting only the structural background/surface/border tokens toward Tekomi's navy via a small, reproducible `color2k`-based script, and generating an even deeper navy variant for the new `.dark`. The teal accent is swapped for Radix Colors' existing "Cyan" scale (closest built-in match to Tekomi's `#11B8C8`). Semantic colors (error/warning/info/AI) are copied from the current dark mode unchanged — no hue shift, since their meaning must not change.

**Tech Stack:** SCSS custom properties, Tailwind CSS (`tailwindcss` config), `color2k` (already a project dependency) for the one-off generation script, Rails migration for the widget default, plain Ruby constant for the portal default.

**Spec:** `docs/superpowers/specs/2026-08-26-tekomi-theme-design.md`

## Global Constraints

- No new heading font (InterDisplay stays; do not add Manrope).
- Navy background applies to every screen, in both light and dark mode (confirmed twice with the user) — do not scope it to chrome/sidebar only.
- Widget (`Channel::WebWidget#widget_color`) and Portal (`Portal::DEFAULT_COLOR`) changes are **default values only** — the existing per-inbox/per-portal ColorPicker customization must keep working exactly as before.
- Semantic colors (`iris`/AI, `ruby`/error, `amber`/warning, `blue`/info, `violet`) keep their current hue — only their *slot* (light vs dark) may change, never their meaning.
- Legacy `woot-*` scale (5 files) is out of scope — do not touch it.
- Per CLAUDE.md: prefer existing dependencies over hand-rolled code (`color2k`, Radix Colors' Cyan scale) — do not hand-invent color math or a new palette from scratch. Per CLAUDE.md: do not add new RSpec/JS test files for this change unless a task below explicitly says to — verification uses lint/build/`rails runner`/manual QA instead.
- Border-radius changes go through `tailwind.config.js`'s scale (`theme.extend.borderRadius`) — never edit individual component `rounded-*` class usages; this also means the change automatically applies to the widget (it's covered by the same Tailwind config and uses `rounded-*` classes, not hardcoded `border-radius` CSS, confirmed during planning).

---

## File Structure

| File | Responsibility |
|---|---|
| `docs/superpowers/plans/2026-08-26-tekomi-theme-conversion.md` | This plan (no code) |
| `app/javascript/dashboard/assets/scss/_next-colors.scss` | All color token values — teal→cyan swap, navy retint of structural tokens, semantic tokens copied from current `.dark` into the new `:root` |
| `tailwind.config.js` | `borderRadius` scale bump, new `boxShadow.brand` navy shadow token |
| `db/migrate/<timestamp>_change_default_widget_color_to_tekomi_teal.rb` | Changes the `widget_color` column default on `channel_web_widgets` |
| `app/models/channel/web_widget.rb` | No code change needed beyond the schema annotation the migration regenerates (default lives in the DB column, not the model) |
| `app/models/portal.rb` | `DEFAULT_COLOR` constant value |

No new files are created inside the app itself. The `color2k`-based generator script used in Task 2 is a one-off, run locally to produce values to paste in — it is written and run from the plan/session, not committed to the repo (there is no `scripts/` convention in this codebase for throwaway generation tools; see File Structure — it's intentionally not listed as a repo file).

---

### Task 1: Swap the teal accent scale to Radix Cyan

**Files:**
- Modify: `app/javascript/dashboard/assets/scss/_next-colors.scss` (the 12 `--teal-*` lines in the `:root` block, and the 12 `--teal-*` lines in the `.dark` block)

**Interfaces:**
- Consumes: nothing (standalone value swap)
- Produces: `--teal-1` … `--teal-12` (both modes) now hold Radix "Cyan" values instead of Radix "Teal" values. Every downstream consumer (`n-teal-*` Tailwind classes, ~50+ components incl. `Button.vue`'s default/primary variant) picks this up automatically — no component code changes.

- [ ] **Step 1: Locate the current teal blocks**

Run: `grep -n -- "--teal-" "app/javascript/dashboard/assets/scss/_next-colors.scss"`

Expected: 24 matches — 12 in the `:root` block (around line 71–82) and 12 in the `.dark` block (around line 223–234).

- [ ] **Step 2: Replace the `:root` teal block**

Replace the 12 `--teal-N` lines inside `:root` with these exact values (Radix Colors "Cyan" light scale, converted from hex to space-separated RGB):

```scss
    --teal-1: 250 253 254;
    --teal-2: 242 250 251;
    --teal-3: 222 247 249;
    --teal-4: 202 241 246;
    --teal-5: 181 233 240;
    --teal-6: 157 221 231;
    --teal-7: 125 206 220;
    --teal-8: 61 185 207;
    --teal-9: 0 162 199;
    --teal-10: 7 151 185;
    --teal-11: 16 125 152;
    --teal-12: 13 60 72;
```

- [ ] **Step 3: Replace the `.dark` teal block**

Replace the 12 `--teal-N` lines inside `.dark` with these exact values (Radix Colors "Cyan" dark scale):

```scss
    --teal-1: 11 22 26;
    --teal-2: 16 27 32;
    --teal-3: 8 44 54;
    --teal-4: 0 56 72;
    --teal-5: 0 69 88;
    --teal-6: 4 84 104;
    --teal-7: 18 103 126;
    --teal-8: 17 128 156;
    --teal-9: 0 162 199;
    --teal-10: 35 175 208;
    --teal-11: 76 204 230;
    --teal-12: 182 236 247;
```

- [ ] **Step 4: Verify no old teal values remain**

Run: `grep -n -- "--teal-9: 18 165 148" "app/javascript/dashboard/assets/scss/_next-colors.scss"`

Expected: no output (the old Radix Teal value is gone from both blocks).

- [ ] **Step 5: Commit**

```bash
git add app/javascript/dashboard/assets/scss/_next-colors.scss
git commit -m "style: swap teal accent scale to Radix Cyan for Tekomi rebrand"
```

---

### Task 2: Generate and apply the navy-tinted structural palette

**Files:**
- Modify: `app/javascript/dashboard/assets/scss/_next-colors.scss` (structural background/surface/border/alpha/solid/gray tokens in `:root`; same tokens in `.dark`; plus copying semantic/text tokens from the current `.dark` into the new `:root`)

**Interfaces:**
- Consumes: `color2k`'s `mix`, `getContrast`, `parseToRgba` (already in `package.json` dependencies — do not add a new package)
- Produces: navy-hued `--background-color`, `--surface-1/2/active`, `--card-color`, `--solid-1/2/3/active`, `--solid-blue-2`, `--label-background`, `--border-weak/strong`, `--button-color/hover-color`, `--gray-1..12`, `--alpha-1/2/3`, `--black-alpha-1/2`, `--overlay`, `--overlay-avatar` in both `:root` and `.dark`; unchanged-hue semantic tokens (`--slate-*`, `--iris-*`, `--blue-*`, `--ruby-*`, `--amber-*`, `--violet-*`, `--text-blue/purple/amber`, `--border-blue-strong`, `--solid-amber/blue/red/iris/purple`) now identical between `:root` and `.dark` (both equal to today's `.dark` values)

- [ ] **Step 1: Write the generator script**

Create a local scratch file (not committed) at, e.g., `/tmp/generate-tekomi-palette.js`, with this content:

```js
// Generates navy-tinted CSS variable values for _next-colors.scss.
// Run from the repo root: node /tmp/generate-tekomi-palette.js
const { mix, getContrast, parseToRgba } = require('color2k');

const NAVY_ROOT = '#123258'; // new :root ("medium navy") anchor
const NAVY_DARK = '#0B1F3A'; // new .dark ("deep navy") anchor
const WEIGHT = 0.4; // fraction of the original value kept; rest is the navy anchor

// Current .dark values (already light-text-safe) for every structural
// token that needs to shift hue toward navy in BOTH new modes.
// format: 'space' = "R G B" | 'comma4' = "R, G, B, A"
const HUE_SHIFT = [
  ['--background-color', '28 29 32', 'space'],
  ['--surface-1', '20 21 23', 'space'],
  ['--surface-2', '22 23 26', 'space'],
  ['--surface-active', '53 57 66', 'space'],
  ['--card-color', '28 30 34', 'space'],
  ['--solid-1', '23 23 26', 'space'],
  ['--solid-2', '29 30 36', 'space'],
  ['--solid-3', '44 45 54', 'space'],
  ['--solid-active', '53 57 66', 'space'],
  ['--solid-blue-2', '26 29 35', 'space'],
  ['--label-background', '36 38 45', 'space'],
  ['--border-weak', '31 31 37', 'space'],
  ['--border-strong', '46 45 50', 'space'],
  ['--button-color', '42 43 51', 'space'],
  ['--gray-1', '17 17 17', 'space'],
  ['--gray-2', '25 25 25', 'space'],
  ['--gray-3', '34 34 34', 'space'],
  ['--gray-4', '42 42 42', 'space'],
  ['--gray-5', '49 49 49', 'space'],
  ['--gray-6', '58 58 58', 'space'],
  ['--gray-7', '72 72 72', 'space'],
  ['--gray-8', '96 96 96', 'space'],
  ['--gray-9', '110 110 110', 'space'],
  ['--gray-10', '123 123 123', 'space'],
  ['--gray-11', '180 180 180', 'space'],
  ['--gray-12', '238 238 238', 'space'],
  ['--alpha-1', '35, 36, 42, 0.8', 'comma4'],
  ['--alpha-2', '147, 153, 176, 0.12', 'comma4'],
  ['--alpha-3', '33, 34, 38, 0.95', 'comma4'],
  ['--black-alpha-1', '0, 0, 0, 0.3', 'comma4'],
  ['--black-alpha-2', '0, 0, 0, 0.2', 'comma4'],
  ['--overlay', '0, 0, 0, 0.4', 'comma4'],
  ['--overlay-avatar', '0, 0, 0, 0.05', 'comma4'],
  ['--button-hover-color', '0, 0, 0, 0.15', 'comma4'],
];

// slate-12 is reused verbatim as :root's primary text color (Step 3 below).
// Needed here only to contrast-check the generated backgrounds against it.
const SLATE_12 = '237 238 240';

function parseSpaceOrComma(value) {
  const parts = value.split(',').length > 1
    ? value.split(',').map((s) => s.trim())
    : value.trim().split(/\s+/);
  const [r, g, b, a] = parts.map(Number);
  return { r, g, b, a: a === undefined ? 1 : a };
}

function toRgbString({ r, g, b }) {
  return `rgb(${Math.round(r)}, ${Math.round(g)}, ${Math.round(b)})`;
}

function shiftHue(value, format, anchor) {
  const { r, g, b, a } = parseSpaceOrComma(value);
  const mixed = mix(`rgb(${r}, ${g}, ${b})`, anchor, WEIGHT);
  const [mr, mg, mb] = parseToRgba(mixed);
  const rr = Math.round(mr);
  const gg = Math.round(mg);
  const bb = Math.round(mb);
  if (format === 'space') return `${rr} ${gg} ${bb}`;
  return `${rr}, ${gg}, ${bb}, ${a}`;
}

function printBlock(label, anchor) {
  console.log(`\n/* ---- ${label} ---- */`);
  for (const [name, value, format] of HUE_SHIFT) {
    console.log(`    ${name}: ${shiftHue(value, format, anchor)};`);
  }
}

printBlock(':root (medium navy)', NAVY_ROOT);
printBlock('.dark (deep navy)', NAVY_DARK);

console.log('\n/* ---- Contrast check: slate-12 text vs backgrounds (need >= 4.5) ---- */');
const textRgb = toRgbString(parseSpaceOrComma(SLATE_12));
for (const [label, anchor] of [[':root', NAVY_ROOT], ['.dark', NAVY_DARK]]) {
  for (const name of ['--background-color', '--surface-1', '--card-color']) {
    const [, value] = HUE_SHIFT.find(([n]) => n === name);
    const bg = toRgbString(parseSpaceOrComma(shiftHue(value, 'comma4', anchor)));
    const ratio = getContrast(textRgb, bg);
    console.log(`${label} ${name}: ${ratio.toFixed(2)}:1${ratio < 4.5 ? '  <-- BELOW AA, adjust WEIGHT' : ''}`);
  }
}
```

- [ ] **Step 2: Run the script from the repo root**

Run: `node /tmp/generate-tekomi-palette.js`

Expected: two blocks of `--name: value;` lines (one per mode) plus a contrast report where every ratio is `>= 4.5`. If any ratio is below 4.5, lower `WEIGHT` (e.g. to `0.3`) and re-run before proceeding — do not paste in values that fail the check.

- [ ] **Step 3: Apply the `:root` output**

In `app/javascript/dashboard/assets/scss/_next-colors.scss`, inside the `:root` block:
1. Replace each of the 33 tokens listed in `HUE_SHIFT` with the script's `:root (medium navy)` output line for that token name.
2. Copy these tokens' values **verbatim from the current `.dark` block** (no computation — literally copy the line down): `--slate-1` … `--slate-12`, `--iris-1` … `--iris-12`, `--blue-1` … `--blue-12`, `--ruby-1` … `--ruby-12`, `--amber-1` … `--amber-12`, `--violet-1` … `--violet-12`, `--text-blue`, `--text-purple`, `--text-amber`, `--border-blue-strong`, `--solid-amber`, `--solid-blue`, `--solid-red`, `--solid-iris`, `--solid-purple`.
3. Leave unchanged (already identical or already dark-canvas-appropriate in both modes today): `--border-container`, `--white-alpha`, `--border-blue`, `--background-input-box`, `--solid-amber-button`, `--label-border`.

- [ ] **Step 4: Apply the `.dark` output**

In the `.dark` block, replace each of the 33 `HUE_SHIFT` tokens with the script's `.dark (deep navy)` output line. Everything else in `.dark` (slate, iris, blue, ruby, amber, violet, text-*, solid-amber/blue/red/iris/purple, border-blue-strong) stays exactly as it is today — no edits.

- [ ] **Step 5: Confirm the file still parses as valid SCSS**

Run: `pnpm exec sass --no-source-map --stdout app/javascript/dashboard/assets/scss/_next-colors.scss > /dev/null`

Expected: exits 0, no syntax errors. (If the `sass` binary isn't available via `pnpm exec`, instead run `pnpm dev` briefly and confirm the Vite dev server compiles without a SCSS error, then stop it.)

- [ ] **Step 6: Visual smoke check**

Run: `pnpm dev` (or `overmind start -f ./Procfile.dev` per CLAUDE.md), open the dashboard in a browser, and confirm:
- The page background, sidebar, and conversation panel are all navy (not partially white).
- Toggling dark mode visibly deepens the navy (it should not look identical to light mode).
- Primary text is legible (light text on navy) in both modes.
- A `bg-n-solid-blue` surface (e.g. an outgoing agent message bubble) still shows readable text — this is the pairing most likely to break if Step 3/4 were applied incorrectly (see spec's contrast risk note).

- [ ] **Step 7: Commit**

```bash
git add app/javascript/dashboard/assets/scss/_next-colors.scss
git commit -m "style: retint background/surface/border tokens to Tekomi navy"
```

---

### Task 3: Extend the Tailwind radius scale and add the brand shadow

**Files:**
- Modify: `tailwind.config.js:195-205` (screens block, insert `borderRadius` as a sibling key) and `tailwind.config.js:220-263` (keyframes/animation area, insert `boxShadow` as a sibling key)

**Interfaces:**
- Consumes: nothing
- Produces: Tailwind utilities `rounded-md`/`rounded-lg`/`rounded-xl`/`rounded-2xl` now resolve to larger pixel values app-wide (dashboard, portal, and widget, since all three share this config); new utility `shadow-brand`

- [ ] **Step 1: Add the `borderRadius` extension**

In `tailwind.config.js`, inside `theme: { extend: { ... } }` (the same object that already holds `fontFamily`, `fontWeight`, etc. — see `tailwind.config.js:41-55`), add:

```js
      borderRadius: {
        md: '10px',
        lg: '16px',
        xl: '20px',
        '2xl': '24px',
      },
```

- [ ] **Step 2: Add the `boxShadow` extension**

In the same `theme.extend` object, add:

```js
      boxShadow: {
        brand: '0 18px 50px -20px rgba(11, 31, 58, 0.28)',
      },
```

- [ ] **Step 3: Verify the config loads**

Run: `pnpm exec tailwindcss -i ./app/javascript/dashboard/assets/scss/dashboard.scss -o /tmp/tw-check.css --config tailwind.config.js 2>&1 | tail -30`

Expected: no errors; `/tmp/tw-check.css` is generated. (Adjust the `-i` entry path if `dashboard.scss` isn't the real entry — run `grep -rn "tailwindcss" vite.config.*` first if unsure which file to point at.)

- [ ] **Step 4: Confirm the scale bump reaches a real component**

Run: `pnpm dev`, open any screen with a card or button (e.g. the conversation list), and confirm corners are visibly rounder than before (buttons ~16px radius, not the previous ~8px). Also open the widget preview (Inbox settings → Website channel → widget preview) and confirm its bubbles/inputs picked up the same rounding, since it shares this config — this confirms no separate widget-specific radius task is needed.

- [ ] **Step 5: Commit**

```bash
git add tailwind.config.js
git commit -m "style: extend border-radius scale and add brand shadow for Tekomi rebrand"
```

---

### Task 4: Change the widget's default accent color

**Files:**
- Create: `db/migrate/<YYYYMMDDHHMMSS>_change_widget_color_default_to_tekomi_teal.rb`
- Modify: `db/schema.rb` (regenerated by running the migration — do not hand-edit)

**Interfaces:**
- Consumes: nothing
- Produces: new `Channel::WebWidget` records default to `widget_color = '#11B8C8'`; existing rows are untouched (matches the spec's "default only" decision)

- [ ] **Step 1: Confirm the current default**

Run: `bin/rails runner "puts Channel::WebWidget.column_defaults['widget_color']"`

Expected: `#1f93ff`

- [ ] **Step 2: Generate the migration**

Run: `bin/rails generate migration ChangeWidgetColorDefaultToTekomiTeal`

This creates `db/migrate/<timestamp>_change_widget_color_default_to_tekomi_teal.rb`. Replace its contents with:

```ruby
class ChangeWidgetColorDefaultToTekomiTeal < ActiveRecord::Migration[7.1]
  def up
    change_column_default :channel_web_widgets, :widget_color, from: '#1f93ff', to: '#11B8C8'
  end

  def down
    change_column_default :channel_web_widgets, :widget_color, from: '#11B8C8', to: '#1f93ff'
  end
end
```

(Table name confirmed as `channel_web_widgets` via `db/schema.rb:727` during planning.)

- [ ] **Step 3: Run the migration**

Run: `bin/rails db:migrate`

Expected: migration reports as migrated; `db/schema.rb`'s `widget_color` default for the widget table updates to `"#11B8C8"`.

- [ ] **Step 4: Verify the new default**

Run: `bin/rails runner "puts Channel::WebWidget.column_defaults['widget_color']"`

Expected: `#11B8C8`

- [ ] **Step 5: Verify an existing row is unaffected**

Run: `bin/rails runner "puts Channel::WebWidget.first&.widget_color || 'no widgets in DB yet — skip, default-only change confirmed by Step 4'"`

Expected: either an existing (old) color, unchanged, or the skip message if the dev DB has no widget channels yet — either way, no existing row should silently become `#11B8C8`.

- [ ] **Step 6: Commit**

```bash
git add db/migrate db/schema.rb
git commit -m "feat: default new widgets to Tekomi teal accent color"
```

---

### Task 5: Change the portal's default accent color

**Files:**
- Modify: `app/models/portal.rb` (the `DEFAULT_COLOR` constant)

**Interfaces:**
- Consumes: nothing
- Produces: `Portal#color` now falls back to Tekomi teal for any portal that hasn't set its own `color`

- [ ] **Step 1: Find the current constant**

Run: `grep -n "DEFAULT_COLOR" app/models/portal.rb`

Expected: one line defining `DEFAULT_COLOR`, plus the `color` method at `app/models/portal.rb:124-126` that falls back to it (`self[:color].presence || DEFAULT_COLOR`).

- [ ] **Step 2: Update the constant**

Change the `DEFAULT_COLOR` value to `'#11B8C8'` (Tekomi teal), keeping its existing format (string, same constant name, same location).

- [ ] **Step 3: Verify**

Run: `bin/rails runner "puts Portal.new.color"`

Expected: `#11B8C8`

- [ ] **Step 4: Verify a portal with a custom color is unaffected**

Run: `bin/rails runner "puts Portal.new(color: '#ff0000').color"`

Expected: `#ff0000` (confirms the fallback-only behavior — customization still wins).

- [ ] **Step 5: Commit**

```bash
git add app/models/portal.rb
git commit -m "feat: default new portals to Tekomi teal accent color"
```

---

### Task 6: Full integration check

**Files:** none (verification only)

**Interfaces:**
- Consumes: everything from Tasks 1–5
- Produces: a pass/fail confirmation that the whole rebrand holds together

- [ ] **Step 1: Run the JS/Vue linter**

Run: `pnpm eslint`

Expected: no new errors introduced by this change (Tasks 1–3 touched no `.vue`/`.js` logic, only SCSS/config, so this should be a no-op check).

- [ ] **Step 2: Run the Ruby linter**

Run: `bundle exec rubocop app/models/portal.rb db/migrate`

Expected: no offenses.

- [ ] **Step 3: Full visual walkthrough**

With `pnpm dev` running, log in and check, per the spec's risk list:
- Dashboard home, conversation list + conversation panel, contact sidebar — navy background, legible text, teal accent on primary buttons/links/active states.
- Settings pages (forms, tables) — navy background holds up, no leftover white panels.
- A modal/dropdown — uses the new `shadow-brand` where applied, rounded per the new radius scale.
- Dark mode toggle — visibly deeper navy than light mode, not identical.
- Create a new inbox (Website channel) — widget color defaults to `#11B8C8`; change it via the ColorPicker and confirm it still saves a custom value.
- Portal settings (if enabterprise/portal is enabled) — new portal defaults to teal; existing/customized portal color unaffected.

- [ ] **Step 4: Record any visual issues found**

If Step 3 surfaces a component with a hardcoded `bg-white`/`text-black`/light-only style that bypasses the token system (called out as a risk in the spec), note the file and add a follow-up task before merging — do not silently patch it outside this plan's review checkpoints.

---

## Self-Review Notes

- **Spec coverage:** accent color (Task 1), navy background both modes (Task 2), typography (no task — spec confirmed no change needed), radius/shadow (Task 3), widget default (Task 4), portal default (Task 5), out-of-scope items (legacy `woot-*`, semantic colors, Manrope) — none touched by any task, confirmed.
- **Correction from the spec's file map:** planning discovered the widget does not use hardcoded `border-radius` CSS — its shape comes from the same Tailwind `rounded-*` classes as the dashboard, so no separate widget SCSS task is needed; Task 3 covers it and Step 4 verifies this directly.
- **Type/name consistency:** `--teal-9`, `--background-color`, `--surface-1`, `DEFAULT_COLOR`, `widget_color` are the same identifiers used consistently across Tasks 1–6.
