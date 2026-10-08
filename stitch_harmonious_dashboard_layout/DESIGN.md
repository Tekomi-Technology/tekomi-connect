---
name: Executive Slate
colors:
  surface: '#f8f9ff'
  surface-dim: '#cbdbf5'
  surface-bright: '#f8f9ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#eff4ff'
  surface-container: '#e5eeff'
  surface-container-high: '#dce9ff'
  surface-container-highest: '#d3e4fe'
  on-surface: '#0b1c30'
  on-surface-variant: '#464555'
  inverse-surface: '#213145'
  inverse-on-surface: '#eaf1ff'
  outline: '#777587'
  outline-variant: '#c7c4d8'
  surface-tint: '#4d44e3'
  primary: '#3525cd'
  on-primary: '#ffffff'
  primary-container: '#4f46e5'
  on-primary-container: '#dad7ff'
  inverse-primary: '#c3c0ff'
  secondary: '#565e74'
  on-secondary: '#ffffff'
  secondary-container: '#dae2fd'
  on-secondary-container: '#5c647a'
  tertiary: '#3130c0'
  on-tertiary: '#ffffff'
  tertiary-container: '#4b4dd8'
  on-tertiary-container: '#d9d8ff'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#e2dfff'
  primary-fixed-dim: '#c3c0ff'
  on-primary-fixed: '#0f0069'
  on-primary-fixed-variant: '#3323cc'
  secondary-fixed: '#dae2fd'
  secondary-fixed-dim: '#bec6e0'
  on-secondary-fixed: '#131b2e'
  on-secondary-fixed-variant: '#3f465c'
  tertiary-fixed: '#e1e0ff'
  tertiary-fixed-dim: '#c0c1ff'
  on-tertiary-fixed: '#07006c'
  on-tertiary-fixed-variant: '#2f2ebe'
  background: '#f8f9ff'
  on-background: '#0b1c30'
  surface-variant: '#d3e4fe'
typography:
  display-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 36px
    fontWeight: '700'
    lineHeight: 44px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 30px
    fontWeight: '700'
    lineHeight: 38px
    letterSpacing: -0.02em
  headline-lg-mobile:
    fontFamily: Plus Jakarta Sans
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 32px
    letterSpacing: -0.01em
  headline-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
    letterSpacing: -0.015em
  headline-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
    letterSpacing: -0.01em
  title-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: '600'
    lineHeight: 24px
    letterSpacing: -0.005em
  title-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
    letterSpacing: 0em
  body-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
    letterSpacing: 0em
  body-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
    letterSpacing: 0em
  body-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 18px
    letterSpacing: 0.01em
  label-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 13px
    fontWeight: '500'
    lineHeight: 18px
    letterSpacing: 0.01em
  label-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 11px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.04em
  code-sm:
    fontFamily: JetBrains Mono
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1.5rem
  gutter-sm: 1rem
  gutter-lg: 2rem
  margin: 2rem
  margin-mobile: 1rem
  margin-tablet: 1.5rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2rem
---

## Brand & Style

### Personality & Emotional Response
The design system projects clinical precision, quiet confidence, and operational authority. It caters to senior operators, data analysts, and platform administrators who require high-density data visualization without visual fatigue. The interface creates an environment of controlled power—delivering instant situational awareness, low-friction task execution, and refined craft.

### Design Movement: Modern Corporate Precision
This system merges contemporary enterprise minimalism with high-end digital instrument styling:
- **Structural Integrity:** Razor-thin boundaries and calibrated structural containers prioritize spatial orientation over decorative flourishes.
- **Micro-Contrast Accents:** Strategic bursts of luminous violet-indigo guide user focus toward active states, primary workflows, and key metrics.
- **Architectural Hierarchy:** A distinct division of planes separates persistent context (navigation and global controls) from fluid canvas workspaces (analytics, data grids, and configuration flows).

## Colors

### Palette Strategy
The palette balances deep navy-slate foundations with pure whites and cool neutrals, punctuated by an electric indigo-violet accent engine:

- **Primary (`#4F46E5` / `#6366F1`):** The operational driver. Used strictly for high-priority calls to action, focus rings, active navigation pills, and critical interactive nodes. The lighter tertiary violet (`#6366F1`) handles hover states and subtle glow accents.
- **Secondary & Structural Slate (`#0F172A` / `#1E293B`):** Establishes typographic hierarchy and enterprise weight. `#0F172A` is reserved for primary headlines, critical data values, and dark-theme chrome elements. `#1E293B` governs subheadings and secondary container framing.
- **Neutrals & Surfaces (`#F8FAFC`, `#FFFFFF`, `#F1F5F9`, `#E2E8F0`):** `#F8FAFC` provides a calm, cool-tinted canvas background that keeps white (`#FFFFFF`) cards and floating panels distinct. `#E2E8F0` serves as the precise boundary layer for borders, dividers, and ghost outlines.
- **Semantic Signals:** Success (`#10B981`), Warning (`#F59E0B`), and Destructive (`#EF4444`) tones are calibrated to identical visual luminance so they sit seamlessly alongside the core indigo accents.

## Typography

### Structural Hierarchy & Legibility
Plus Jakarta Sans provides geometric balance with wide apertures and clean terminals, making high-density data tables and admin configurations effortless to scan:

- **Display & Headlines:** Tightly tracked with negative letter-spacing to produce an authoritative editorial presence on high-level KPI summaries and dashboard overviews.
- **Body & Data:** Standard neutral tracking ensuring zero eye-strain during prolonged operational analysis.
- **Labels & Overlines:** Micro-labels utilize semi-bold weightings with slight positive letter tracking (`0.04em`) to maintain legibility when converted to uppercase or placed alongside metric badges.
- **Tabular Data:** JetBrains Mono is deployed for cryptographic keys, resource IDs, server timestamps, and monospaced financial data columns.

## Layout & Spacing

### Layout Architecture
The dashboard runs on an anchored dual-axis layout consisting of a fixed vertical sidebar (260px wide standard, collapsing to an 72px icon rail on compact displays), an elevated top header (64px height), and a fluid primary canvas:

- **Top Header Bar:** Spans the workspace with horizontal inline alignments: left-anchored breadcrumbs and search command palette (`Ctrl+K`), right-anchored notifications, system health indicators, and user workspace controls.
- **Dashboard Grid:** Standard 12-column fluid grid system across desktop viewports with a 24px (`1.5rem`) gutter rhythm.
- **Responsive Adaptations:**
  - **Desktop (1280px+):** Sidebar expanded at 260px; canvas margin set to `2rem`; cards span full 12-column sub-divisions.
  - **Tablet (768px - 1279px):** Sidebar auto-collapses to 72px icon rail; canvas margin drops to `1.5rem`; multi-column metric modules reflow from 4 columns to 2 columns.
  - **Mobile (<768px):** Sidebar off-canvases behind a slide-in drawer; canvas margin set to `1rem`; grid reflows to a single unified column; top navigation condenses search to an icon trigger.

## Elevation & Depth

### Atmospheric Depth & Edge Definition
This design system avoids heavy shadows, instead using low-contrast border rings paired with diffused, indigo-tinted ambient depth to distinguish operational tiers:

- **Level 0 (Canvas Base):** Surface color `#F8FAFC`. Zero elevation, pure flat plane.
- **Level 1 (Cards, Metric Containers, Sidebar Rail):** Surface `#FFFFFF`. Encased in a crisp `1px solid #E2E8F0` border ring. Paired with a soft ambient shadow: `0 1px 3px 0 rgba(15, 23, 42, 0.04), 0 1px 2px -1px rgba(15, 23, 42, 0.02)`.
- **Level 2 (Dropdowns, Popovers, Filter Menus):** Surface `#FFFFFF`. Border `1px solid #E2E8F0`. Shadow: `0 10px 15px -3px rgba(15, 23, 42, 0.06), 0 4px 6px -4px rgba(15, 23, 42, 0.04)`.
- **Level 3 (Command Palette, Modal Dialogs, Floating Drawers):** Surface `#FFFFFF`. Shadow: `0 20px 25px -5px rgba(15, 23, 42, 0.08), 0 8px 10px -6px rgba(15, 23, 42, 0.04)`. Backdrops feature a soft blur overlay using `rgba(15, 23, 42, 0.4)` with `backdrop-filter: blur(4px)`.
- **Focus Rings & Micro-Glow:** All active interactions and focus states use an outer glow ring: `0 0 0 3px rgba(99, 102, 241, 0.2)`.

## Shapes

### Balanced Rounded Geometry
The system uses balanced radius tokens to soften analytical dashboard data while maintaining technical rigor:

- **Standard Elements (`rounded-md` / 0.5rem):** Form inputs, default buttons, inline badges, and table cell highlights.
- **Large Panels (`rounded-lg` / 1rem):** Dashboard cards, modal sheets, floating popovers, and workspace containers.
- **Extra Large Containers (`rounded-xl` / 1.5rem):** Welcome banners, empty-state illustrations, and feature spotlight callouts.
- **Interactive Micro-Pills (`rounded-full` / 9999px):** Status indicator dots, user avatar badges, and analytical count chips.

## Components

### Buttons
- **Primary:** Background `#4F46E5`, foreground `#FFFFFF`, border `transparent`. Hover: `#4338CA`. Active press: slight scale down (`0.98`). Focus: `0 0 0 3px rgba(99, 102, 241, 0.25)`.
- **Secondary / Outline:** Background `#FFFFFF`, foreground `#0F172A`, border `1px solid #E2E8F0`. Hover: background `#F8FAFC`, border `#CBD5E1`.
- **Ghost:** Background `transparent`, foreground `#64748B`. Hover: background `#F1F5F9`, foreground `#0F172A`.

### Navigation & Sidebar
- **Sidebar Items:** Height 40px, padding `0 12px`, border-radius `0.5rem`. Default text color `#64748B`. Active state: background `rgba(79, 70, 229, 0.08)`, text `#4F46E5`, accompanied by a 3px vertical accent bar on the left edge.
- **Breadcrumbs:** Integrated within top header bar; muted `#64748B` typography separated by `/` or chevron icons, culminating in a semi-bold `#0F172A` current-page anchor.

### Search & Global Header
- **Command Palette Trigger:** Inset background `#F1F5F9`, border `1px solid #E2E8F0`, padding `6px 12px`. Contains leading search icon, placeholder text, and a right-aligned kbd token (`⌘K` / `Ctrl+K`) with `#FFFFFF` fill and `#CBD5E1` border.
- **Notification & Profile Dropdown:** Notification bell includes an absolute-positioned 6px `#6366F1` pulse dot. Profile menu trigger displays a 32px circular avatar with a subtle ring border (`2px solid #E2E8F0`).

### Content Cards & Metric Widgets
- **Structure:** Background `#FFFFFF`, border `1px solid #E2E8F0`, border-radius `1rem`, padding `1.5rem`.
- **Metric Header:** Displays small uppercase category label (`label-sm`), main quantitative readout (`headline-md`), and inline growth pills (e.g., green `+12.4%` badge with `#ECFDF5` background and `#065F46` text).

### Form Controls & Inputs
- **Input Fields:** Height 40px, background `#FFFFFF`, border `1px solid #E2E8F0`, text `#0F172A`, placeholder `#94A3B8`. Hover: border `#CBD5E1`. Focus: border `#4F46E5`, focus ring `0 0 0 3px rgba(99, 102, 241, 0.15)`.
- **Checkboxes & Radios:** 16px square/circle, border `1px solid #CBD5E1`. Checked state: `#4F46E5` fill with pure white tick icon.

### Data Grids & Tables
- **Header Row:** Background `#F8FAFC`, border-bottom `1px solid #E2E8F0`, typography `label-sm` in `#64748B`.
- **Body Rows:** Height 52px, alternating hover background `#F8FAFC`, divider `1px solid #F1F5F9`. Cell padding `12px 16px`.