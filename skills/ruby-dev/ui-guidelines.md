# UI Guidelines

Portable view-layer conventions for personal Ruby projects — flat BEM, CSS variables as a component interface, semantic + accessible HTML, and how presentational changes pass the `/ruby-dev` review gate.

<!-- Section Index (for selective loading — read index, then load sections by line range)
| Section                              | Keywords                                                              |
| ------------------------------------ | -------------------------------------------------------------------- |
| Universal core                       | BEM, flat CSS, specificity, !important, --_ vars, inline styles       |
| Semantic HTML & accessibility        | heading hierarchy, aria-label, color contrast, visually-hidden        |
| Numeric & comments                   | tabular-nums, ERB comments, HTML comments                             |
| Optional: Rails-only                 | ViewComponent, BEM helpers, Stimulus, Turbo, content_for, Zest        |
| Presentational verification          | review gate, visual checklist, screenshot, Playwright, rackup         |
-->

The examples below are drawn from the wc26-bracket project (Sinatra + ERB + hand-rolled CSS). They are **illustrative patterns, not wc26-specific rules** — apply the same shapes to any Ruby view layer.

---

## Universal core

Applies to any Ruby project that renders HTML/CSS (Sinatra, Roda, Rack, plain ERB, or Rails).

### Keep CSS flat with BEM naming

Nesting and descendant selectors raise specificity, which makes later overrides require hacks (or `!important`). Use flat [BEM](https://getbem.com/) class names that encode structure in the name instead of the selector tree.

wc26's scoring panel is a good model — every element is a flat `block__element` class:

```css
/* ✅ Flat BEM — low, predictable specificity */
.scoring-panel { /* block */ }
.scoring-panel__title { /* element */ }
.scoring-panel__list { /* element */ }
.scoring-panel__note { /* element */ }
```

```css
/* ❌ Avoid — nesting and descendant selectors leak styles and raise specificity */
.scoring-panel {
  .scoring-panel__list {
    li { /* now hard to override from outside */ }
  }
}
```

Use modifiers (`block__element--variant`) for variants rather than overriding via context:

```css
.badge { /* base */ }
.badge--locked { /* variant */ }
.badge--pts { /* variant */ }
```

### Register a BEM element class instead of bare or descendant selectors

Styling a bare element (`button`, `a`) or a descendant (`.card a`) leaks onto every matching element inside the block and raises specificity. Give the element its own flat class and style that.

```css
/* ❌ Bad — leaks onto every <a> inside .topbar nav, and is hard to override */
.topbar nav a { color: var(--accent-2); }

/* ✅ Good — a named element class scoped to one role */
.topbar__nav-link { color: var(--accent-2); }
```

Pseudo-classes/elements and same-element state classes are the acceptable exceptions:

```css
.topbar__nav-link:hover { text-decoration: underline; }   /* ✅ pseudo-class */
.badge.is-locked { background: #3f3f46; }                  /* ✅ state on same element */
```

### Avoid `!important` on shared classes

`!important` forces the value on every consumer of a shared class; the only way to beat it later is another `!important`. If you reach for it to win a specificity battle, that's a signal the selectors are nested or too specific — flatten them instead. Use a modifier for the variant you actually want.

### Treat CSS variables as a component interface

Define a palette/tokens once (wc26 uses a `:root` block), then let components consume them. For values a component repeats or wants to expose as a knob, use a **private local variable** prefixed `--_`, falling back to the shared token:

```css
/* Shared palette — define once */
:root {
  --bg: #0f172a;
  --panel: #1e293b;
  --accent: #22c55e;
  --border: #334155;
}

/* Component reads a private local that falls back to the palette */
.card {
  --_card-bg: var(--card-bg, var(--panel));
  --_card-border: var(--card-border, var(--border));
  background: var(--_card-bg);
  border: 1px solid var(--_card-border);
}

/* A variant overrides the semantic input, not the raw property */
.card--featured { --card-bg: var(--panel-2); }
```

The `--_` prefix signals "component-local/private"; the un-prefixed name (`--card-bg`) is the public input. This keeps components composable without descendant overrides.

Reach for a local variable whenever a rule repeats the same value (e.g. an icon's `width` and `height`) so there's a single source of truth:

```css
.flag { --_flag-size: 16px; width: var(--_flag-size); height: var(--_flag-size); }
```

### Keep styles out of inline `style` attributes

Inline `style="..."` can't be overridden by a stylesheet without `!important`, bypasses the palette/tokens, and scatters presentation across templates. Move the rule into a BEM class.

```erb
<%# ❌ Bad — bypasses the palette and the cascade %>
<div style="padding: 0.9rem; background: #1e293b; border-radius: 12px;">…</div>

<%# ✅ Good — a class that reads tokens %>
<div class="card">…</div>
```

The one legitimate use is a genuinely *dynamic* value computed from data (e.g. a progress-bar width); even then, prefer setting a CSS variable inline over a raw property.

---

## Semantic HTML & accessibility

### Use semantic elements and a correct heading hierarchy

Choose elements by meaning, not appearance. Start at `<h1>` and never skip levels (`h1` → `h2` → `h3`). For purely visual emphasis with no document-structure meaning, use a `<div>`/`<span>` with a class instead of a heading tag.

```erb
<%# ✅ wc26 leaderboard: h1 for the page, h2 for a subsection %>
<h1>Leaderboard</h1>
<h2>By round</h2>
```

Use `<header>`, `<main>`, `<nav>`, `<section>`, `<aside>`, and `<footer>` for their semantic roles rather than generic `<div>`s where a landmark fits.

### Never signal status by color alone

Pair color with a label, icon, or shape so meaning survives for color-blind and low-vision users, and ensure text meets WCAG AA contrast (4.5:1 body, 3:1 large text).

```erb
<%# ❌ Color is the only signal %>
<span class="badge badge--locked"></span>

<%# ✅ Color plus a text label %>
<span class="badge badge--locked">Locked</span>
```

### `aria-label` only works on interactive/landmark/`role` elements

On a bare `<span>` or `<div>`, `aria-label` is silently ignored, so the label never reaches a screen reader. Either expose a visually-hidden label, or promote the element to an image role.

```erb
<%# ✅ Option 1: visually-hidden text, decorative icon hidden from AT %>
<span class="badge">
  <span class="visually-hidden">Locked</span>
  <span class="badge__icon" aria-hidden="true">🔒</span>
</span>

<%# ✅ Option 2: give the element an image role so aria-label is honored %>
<span class="badge__icon" role="img" aria-label="Locked">🔒</span>
```

---

## Numeric columns & comments

### Use `tabular-nums` for numeric columns

Numbers that line up in a column (scores, points, totals) should use fixed-width figures and right alignment, as wc26's leaderboard does:

```css
.num { text-align: right; font-variant-numeric: tabular-nums; }
```

Follow this existing project pattern rather than introducing a monospace font family for numeric alignment.

### ERB comments for server-side notes, HTML comments only for shipped markup

`<!-- … -->` reaches the browser's view-source; `<% # … %>` does not. Use ERB comments for development notes, business-logic explanations, and anything that shouldn't reach end users. Reserve HTML comments for context that genuinely belongs in the rendered document.

```erb
<%# ✅ Server-side note — never shipped to the browser %>
<%# Scoring rules mirror lib/scoring.rb; keep in sync %>
```

---

## Optional: Rails-only

**Only when the project is Rails.** Plain-ERB/Sinatra projects (like wc26) ignore this section — the universal core above is sufficient. These are short pointers, not a full port; consult `/pi-dev` for the exhaustive treatment.

- **ViewComponents + BEM helpers**: extract reusable UI into `ViewComponent::Base` subclasses with side-car `.css`; generate element classes with the BEM helpers (`block_class`) rather than hand-writing them.
- **Stimulus / Turbo**: use Stimulus controllers and Turbo Frames/Streams for dynamic behavior instead of jQuery/bespoke JS; lazy-load only truly non-critical frames.
- **`content_for :head`**: move view-specific `<style>` out of the body into the document head; wrap conditional styles in the same conditional.
- **Design-token systems (e.g. Zest)**: prefer an existing design system's tokens and components over hand-rolled CSS/glyphs when the project ships one. The universal "CSS variables as interface" pattern is the framework-agnostic version of the same idea.

---

## Presentational verification (the review gate for UI work)

`/ruby-dev` keeps a mandatory human gate before implementation. UI work splits by the **nature** of the change:

- **View logic** (helpers, presenters, scoring like `lib/scoring.rb` — anything with branching) follows normal TDD: write a failing RSpec example, verify red, then get `shipit`.
- **Pure presentation** (CSS, static ERB markup with no branching) has no natural RSpec red. It keeps the **same mandatory pause and the same `shipit` token**, but the "Test-Only Review Package" is replaced by a **visual-verification checklist** — do not fabricate a meaningless RSpec test.

### Visual-verification checklist

Present this at the gate for presentational changes:

- **Rendered states** — every state the change touches (default, hover, locked/disabled, empty, error).
- **Color contrast** — text meets WCAG AA; status is never color-only.
- **Semantic structure** — heading hierarchy intact, landmarks/roles correct, `aria-label` only where honored.
- **Responsive behavior** — layout holds at narrow and wide widths.

### Optional best-effort screenshot

If a local preview/browser is cheaply available, capture a screenshot of the affected states and include it in the review package as rendered evidence — otherwise the written checklist above stands on its own. This is **optional and non-blocking**; the skill must still work with no browser wired up.

- **Playwright MCP** — if available, navigate to the running app and screenshot the affected view.
- **Local preview** — for a Rack/Sinatra app like wc26, boot it (`bundle exec rackup` / the project's run command), open the route, and screenshot.

Embed any captured screenshot inline in the review package so the reviewer sees the rendered result alongside the checklist before giving `shipit`.
